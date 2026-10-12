#include "walletbackend.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

class WalletPlugin :
    public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(
        IID "org.qt-project.Qt.QQmlExtensionInterface"
    )

public:
    void registerTypes(
        const char *uri
    ) override
    {
        qmlRegisterType<WalletBackend>(
            uri,
            1,
            0,
            "WalletBackend"
        );
    }
};

#include "walletplugin.moc"