#!/usr/bin/env python3
"""Test real main.qml functions with deferred wallet and HTTP replies, without secrets/network."""
import os
from pathlib import Path
import re
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QJSEngine, QQmlComponent, QQmlEngine

UI = Path(__file__).resolve().parents[1] / "package/contents/ui"
APP = QGuiApplication([])
SOURCE = (UI / "main.qml").read_text()


class LoginLifecycle(unittest.TestCase):
    def setUp(self):
        self.engine = QJSEngine()
        self.run_js("""
            var root = {sessionPassword: '', accessToken: '', apiStatus: '', apiBusy: false,
                credentialStatus: '', sessionGeneration: 0, lastApiData: null, cycle: '',
                days: [], lessonTimes: []};
            var plasmoid = {configuration: {serverUrl: 'https://school.invalid/', username: 'test'}};
            var refreshTimer = {stop: function(){}, restart: function(){}};
            var Qt = {formatTime: function(){return '12:00'}};
            var console = {log: function(){}, error: function(){}};
            var walletOps = [];
            var walletLoader = {item: {
                loadPassword: function(key, cb){walletOps.push({op:'load', key:key, cb:cb})},
                savePassword: function(key, pw, cb){walletOps.push({op:'save', key:key, pw:pw, cb:cb})},
                deletePassword: function(key, cb){walletOps.push({op:'delete', key:key, cb:cb})}
            }};
            var requests = [];
            function XMLHttpRequest() { requests.push(this); }
            XMLHttpRequest.DONE = 4;
            XMLHttpRequest.prototype.open = function(method, url){this.method=method;this.url=url};
            XMLHttpRequest.prototype.setRequestHeader = function(){};
            XMLHttpRequest.prototype.send = function(body){this.body=body};
            XMLHttpRequest.prototype.reply = function(status, data){
                this.status=status; this.responseText=JSON.stringify(data);
                this.readyState=4; this.onreadystatechange();
            };
            function i18n(s){return s}
            function assert(value, message){if(!value) throw new Error(message)}
            root.applyTimetableData = function(data){root.lastApiData=data};
            ['sessionPassword','apiStatus','apiBusy'].forEach(function(name){
                Object.defineProperty(this, name, {get:function(){return root[name]},
                    set:function(value){root[name]=value}});
            });
        """)
        for name in ["normalizedServerUrl", "walletKey", "savePasswordToWallet",
                     "forgetPasswordAndLogout", "clearLoginSession", "tryAutomaticLogin",
                     "loginToBakalari", "todayForApi", "fetchTimetable"]:
            match = re.search(r"^    function " + name + r"\([^\n]*\) \{.*?^    \}", SOURCE, re.M | re.S)
            self.assertIsNotNone(match, name)
            self.run_js(match.group() + "\nroot." + name + "=" + name + ";")

    def run_js(self, script):
        result = self.engine.evaluate(script)
        self.assertFalse(result.isError(), result.toString())

    def test_logout_ignores_pending_password_read(self):
        self.run_js("""
            root.tryAutomaticLogin(); root.forgetPasswordAndLogout();
            walletOps[0].cb('', 'dummy');
            assert(requests.length === 0 && root.accessToken === '', 'logout revived login');
            assert(walletOps[1].op === 'delete', 'logout did not request deletion');
        """)

    def test_logout_ignores_pending_login_response(self):
        self.run_js("""
            root.sessionPassword='dummy'; root.loginToBakalari(); root.forgetPasswordAndLogout();
            requests[0].reply(200, {access_token:'dummy-token'});
            assert(root.accessToken === '' && requests.length === 1, 'late login accepted');
            assert(walletOps.length === 1 && walletOps[0].op === 'delete', 'late password save');
        """)

    def test_account_change_rejects_old_reply(self):
        self.run_js("""
            root.sessionPassword='dummy'; root.loginToBakalari();
            plasmoid.configuration.username='other';
            requests[0].reply(200, {access_token:'dummy-token'});
            assert(root.accessToken === '' && walletOps.length === 0, 'old account accepted');
        """)

    def test_success_saves_snapshot_and_fetches_timetable(self):
        self.run_js("""
            root.sessionPassword='dummy'; root.loginToBakalari();
            root.sessionPassword='edited'; requests[0].reply(200, {access_token:'dummy-token'});
            assert(walletOps[0].pw === 'dummy', 'saved a different password');
            assert(root.sessionPassword === '' && requests.length === 2, 'login flow changed');
            assert(requests[1].url.indexOf('/api/3/timetable/actual?date=') > 0, 'wrong API');
            walletOps[0].cb('save failed');
            assert(root.accessToken === 'dummy-token' && root.credentialStatus !== '', 'save failure lost login');
            requests[1].reply(200, {Days: []});
            assert(root.lastApiData !== null, 'timetable was not applied');
        """)

    def test_logout_ignores_pending_timetable(self):
        self.run_js("""
            root.accessToken='dummy-token'; root.fetchTimetable(); root.forgetPasswordAndLogout();
            requests[0].reply(200, {Days: []});
            assert(root.lastApiData === null && root.apiStatus === 'Logged out', 'late timetable applied');
        """)

    def test_missing_storage_allows_session_login(self):
        self.run_js("""
            walletLoader.item=null; root.sessionPassword='dummy'; root.loginToBakalari();
            requests[0].reply(200, {access_token:'dummy-token'});
            assert(root.accessToken === 'dummy-token' && root.credentialStatus !== '', 'storage required');
        """)

    def test_qml_compiles(self):
        engine = QQmlEngine()
        for name in ["main.qml", "configGeneral.qml", "WalletDbus.qml"]:
            component = QQmlComponent(engine, QUrl.fromLocalFile(str(UI / name)))
            while component.isLoading():
                APP.processEvents()
            self.assertFalse(component.isError(), '\n'.join(e.toString() for e in component.errors()))


if __name__ == "__main__":
    unittest.main()
