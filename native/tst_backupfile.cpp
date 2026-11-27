// SPDX-License-Identifier: GPL-3.0-or-later
#include "backupfile.h"

#include <QFile>
#include <QFileInfo>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QTemporaryDir>
#include <QtTest>

class BackupFileTest : public QObject
{
    Q_OBJECT
private:
    BackupFile io;
    static QString status(const QVariantMap &value) { return value.value(QStringLiteral("status")).toString(); }
private slots:
    void roundTrip()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const auto path = dir.filePath(QStringLiteral("backup č.json"));
        const auto url = QUrl::fromLocalFile(path);
        const QString text = QStringLiteral("{\"text\":\"  čćž 日本語 😀\\n\\t<b>literal</b>\"}\n");
        QCOMPARE(status(io.write(url, text, false)), QStringLiteral("ok"));
        const auto read = io.read(url);
        QCOMPARE(status(read), QStringLiteral("ok"));
        QCOMPARE(read.value(QStringLiteral("text")).toString(), text);
        const auto perms = QFileInfo(path).permissions();
        QVERIFY(!(perms & (QFileDevice::ReadGroup | QFileDevice::WriteGroup |
                            QFileDevice::ReadOther | QFileDevice::WriteOther)));
        QCOMPARE(status(io.write(url, QStringLiteral("replacement"), false)), QStringLiteral("exists"));
        QCOMPARE(io.read(url).value(QStringLiteral("text")).toString(), text);
        QCOMPARE(status(io.write(url, QStringLiteral("replacement"), true)), QStringLiteral("ok"));
        QCOMPARE(io.read(url).value(QStringLiteral("text")).toString(), QStringLiteral("replacement"));
    }

    void invalidInputs()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const auto missing = QUrl::fromLocalFile(dir.filePath(QStringLiteral("missing.json")));
        QCOMPARE(status(io.read(missing)), QStringLiteral("invalid-path"));
        QCOMPARE(status(io.read(QUrl(QStringLiteral("https://example.invalid/backup.json")))), QStringLiteral("invalid-path"));
        QCOMPARE(status(io.write(QUrl::fromLocalFile(dir.path()), QStringLiteral("data"), true)), QStringLiteral("invalid-path"));
        QCOMPARE(status(io.write(QUrl(QStringLiteral("https://example.invalid/backup.json")), QStringLiteral("data"), false)), QStringLiteral("invalid-path"));
        QCOMPARE(status(io.write(QUrl::fromLocalFile(dir.filePath(QStringLiteral("missing/backup.json"))), QStringLiteral("data"), false)), QStringLiteral("invalid-path"));

        const auto path = dir.filePath(QStringLiteral("invalid.json"));
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        QCOMPARE(file.write(QByteArray::fromHex("fffeff")), 3);
        file.close();
        QCOMPARE(status(io.read(QUrl::fromLocalFile(path))), QStringLiteral("invalid-utf8"));
        QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
        QCOMPARE(file.write(QByteArray::fromHex("61e282")), 3);
        file.close();
        QCOMPARE(status(io.read(QUrl::fromLocalFile(path))), QStringLiteral("invalid-utf8"));
        const QString malformed(1, QChar(0xd800));
        QCOMPARE(status(io.write(QUrl::fromLocalFile(path), malformed, true)), QStringLiteral("invalid-utf16"));

        const auto link = dir.filePath(QStringLiteral("link.json"));
        QVERIFY(QFile::link(path, link));
        QCOMPARE(status(io.read(QUrl::fromLocalFile(link))), QStringLiteral("invalid-path"));
        QCOMPARE(status(io.write(QUrl::fromLocalFile(link), QStringLiteral("data"), true)), QStringLiteral("invalid-path"));
    }

    void sizeLimit()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const auto path = dir.filePath(QStringLiteral("large.json"));
        const auto url = QUrl::fromLocalFile(path);
        QCOMPARE(status(io.write(url, QStringLiteral("original"), false)), QStringLiteral("ok"));
        const QString large(BackupFile::MaximumBytes / 2 + 1, QChar(0x010d));
        QCOMPARE(status(io.write(url, large, true)), QStringLiteral("too-large"));
        QCOMPARE(io.read(url).value(QStringLiteral("text")).toString(), QStringLiteral("original"));
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        QVERIFY(file.resize(BackupFile::MaximumBytes + 1));
        file.close();
        QCOMPARE(status(io.read(url)), QStringLiteral("too-large"));
    }

    void qmlImport()
    {
        QQmlEngine engine;
        engine.addImportPath(QString::fromUtf8(qgetenv("KOPYPAST_TEST_QML_PATH")));
        QQmlComponent component(&engine);
        component.setData("import io.github.fooftilly.kopypast.fileio 1.0\nBackupFile {}", QUrl());
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        QVERIFY(qobject_cast<BackupFile *>(object.data()));
    }
};

QTEST_GUILESS_MAIN(BackupFileTest)
#include "tst_backupfile.moc"
