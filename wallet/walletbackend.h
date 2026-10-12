#pragma once

#include <QObject>
#include <QString>

class WalletBackend : public QObject
{
    Q_OBJECT

public:
    explicit WalletBackend(QObject *parent = nullptr);

    Q_INVOKABLE QString loadPassword(
        const QString &key
    );

    Q_INVOKABLE bool savePassword(
        const QString &key,
        const QString &password
    );

    Q_INVOKABLE bool deletePassword(
        const QString &key
    );

private:
    static constexpr const char *Folder =
        "Bakalari Plasma Widget";
};
