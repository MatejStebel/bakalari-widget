#include "walletbackend.h"

#include <KWallet>

WalletBackend::WalletBackend(
    QObject *parent
)
    : QObject(parent)
{
}


QString WalletBackend::loadPassword(
    const QString &key
)
{
    KWallet::Wallet *wallet =
        KWallet::Wallet::openWallet(
            KWallet::Wallet::NetworkWallet(),
            0,
            KWallet::Wallet::Synchronous
        );

    if (!wallet) {
        return {};
    }

    const QString folder =
        QString::fromUtf8(Folder);

    if (!wallet->hasFolder(folder)) {
        delete wallet;
        return {};
    }

    if (!wallet->setFolder(folder)) {
        delete wallet;
        return {};
    }

    QString password;

    if (
        wallet->readPassword(
            key,
            password
        ) != 0
    ) {
        delete wallet;
        return {};
    }

    delete wallet;

    return password;
}


bool WalletBackend::savePassword(
    const QString &key,
    const QString &password
)
{
    KWallet::Wallet *wallet =
        KWallet::Wallet::openWallet(
            KWallet::Wallet::NetworkWallet(),
            0,
            KWallet::Wallet::Synchronous
        );

    if (!wallet) {
        return false;
    }

    const QString folder =
        QString::fromUtf8(Folder);

    if (!wallet->hasFolder(folder)) {
        if (!wallet->createFolder(folder)) {
            delete wallet;
            return false;
        }
    }

    if (!wallet->setFolder(folder)) {
        delete wallet;
        return false;
    }

    const bool success =
        wallet->writePassword(
            key,
            password
        ) == 0;

    delete wallet;

    return success;
}


bool WalletBackend::deletePassword(
    const QString &key
)
{
    KWallet::Wallet *wallet =
        KWallet::Wallet::openWallet(
            KWallet::Wallet::NetworkWallet(),
            0,
            KWallet::Wallet::Synchronous
        );

    if (!wallet) {
        return false;
    }

    const QString folder =
        QString::fromUtf8(Folder);

    if (!wallet->hasFolder(folder)) {
        delete wallet;
        return true;
    }

    if (!wallet->setFolder(folder)) {
        delete wallet;
        return false;
    }

    const bool success =
        wallet->removeEntry(key) == 0;

    delete wallet;

    return success;
}
