// SPDX-License-Identifier: GPL-3.0-or-later
#include "sharedlibrary.h"

#include <QFile>
#include <QLockFile>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtTest>

class SharedLibraryTest : public QObject
{
    Q_OBJECT
private:
    QTemporaryDir data;
    SharedLibrary first, second;
    static QString status(const QVariantMap &v) { return v.value(QStringLiteral("status")).toString(); }
    static QString rev(const QVariantMap &v) { return v.value(QStringLiteral("revision")).toString(); }
    static QString text(const QVariantMap &v) { return v.value(QStringLiteral("text")).toString(); }
    static QString content(const QString &title)
    {
        return QStringLiteral("{\"format\":\"io.github.fooftilly.kopypast\",\"version\":1,"
                              "\"snippets\":[{\"id\":\"a\",\"title\":\"%1\",\"text\":\"body\"}]}").arg(title);
    }
    QString path(const QString &name) const
    {
        return data.filePath(QStringLiteral("io.github.fooftilly.kopypast/libraries/") + name + QStringLiteral(".json"));
    }
private slots:
    void initTestCase()
    {
        QVERIFY(data.isValid());
        QVERIFY(qputenv("XDG_DATA_HOME", data.path().toUtf8()));
        QCOMPARE(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation), data.path());
    }

    void staleWriter()
    {
        const auto name = QStringLiteral("work");
        QCOMPARE(status(first.readSnapshot(name)), QStringLiteral("missing"));
        const auto created = first.create(name, content(QStringLiteral("Original")));
        QCOMPARE(status(created), QStringLiteral("ok"));
        QCOMPARE(rev(created).size(), 64);
        QCOMPARE(status(second.create(name, content(QStringLiteral("Other")))), QStringLiteral("exists"));
        const auto a = first.readSnapshot(name);
        const auto b = second.readSnapshot(name);
        QCOMPARE(status(a), QStringLiteral("ok"));
        QCOMPARE(a, b);
        const auto saved = first.commit(name, rev(a), content(QStringLiteral("Changed")));
        QCOMPARE(status(saved), QStringLiteral("ok"));
        QVERIFY(rev(saved) != rev(a));
        QCOMPARE(status(second.commit(name, rev(b), content(QStringLiteral("Stale")))), QStringLiteral("conflict"));
        const auto current = second.readSnapshot(name);
        QCOMPARE(text(current), content(QStringLiteral("Changed")));
        QCOMPARE(rev(current), rev(saved));
        QCOMPARE(rev(second.commit(name, rev(current), text(current))), rev(current));
    }

    void lockContention()
    {
        const auto name = QStringLiteral("locked");
        const auto created = first.create(name, content(QStringLiteral("Original")));
        QCOMPARE(status(created), QStringLiteral("ok"));
        QLockFile lock(path(name) + QStringLiteral(".lock"));
        lock.setStaleLockTime(0);
        QVERIFY(lock.tryLock(0));
        QCOMPARE(status(second.commit(name, rev(created), content(QStringLiteral("Other")))), QStringLiteral("busy"));
        QCOMPARE(text(first.readSnapshot(name)), content(QStringLiteral("Original")));
        lock.unlock();
        QCOMPARE(status(second.commit(name, rev(created), content(QStringLiteral("Other")))), QStringLiteral("ok"));
    }

    void invalidAndRecovery()
    {
        const auto name = QStringLiteral("recovery");
        const auto created = first.create(name, content(QStringLiteral("Original")));
        QCOMPARE(status(created), QStringLiteral("ok"));
        QCOMPARE(status(first.commit(name, rev(created), QStringLiteral("[]"))), QStringLiteral("invalid-format"));
        QCOMPARE(text(first.readSnapshot(name)), content(QStringLiteral("Original")));
        QFile file(path(name));
        QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
        QCOMPARE(file.write("broken"), 6);
        file.close();
        const auto damaged = first.readSnapshot(name);
        QCOMPARE(status(damaged), QStringLiteral("invalid-format"));
        QCOMPARE(text(damaged), QStringLiteral("broken"));
        QCOMPARE(status(second.commit(name, rev(created), content(QStringLiteral("Other")))), QStringLiteral("invalid-format"));
        QCOMPARE(status(second.create(name, content(QStringLiteral("Other")))), QStringLiteral("exists"));
        QCOMPARE(text(first.readSnapshot(name)), QStringLiteral("broken"));
    }

    void invalidNames()
    {
        for (const auto &name : {QString(), QStringLiteral("../escape"), QStringLiteral("a/b"),
                                 QStringLiteral("Work"), QStringLiteral("a\n"), QString(65, QChar('a'))}) {
            QCOMPARE(status(first.readSnapshot(name)), QStringLiteral("invalid-name"));
            QCOMPARE(status(first.create(name, content(QStringLiteral("Original")))), QStringLiteral("invalid-name"));
        }
        QCOMPARE(status(first.commit(QStringLiteral("absent"), QString(), content(QStringLiteral("Original")))),
                 QStringLiteral("missing"));
    }

    void watchAtomicUpdates()
    {
        const auto name = QStringLiteral("watched");
        auto created = first.create(name, content(QStringLiteral("Original")));
        QCOMPARE(status(created), QStringLiteral("ok"));
        QSignalSpy changed(&second, &SharedLibrary::snapshotChanged);
        QVERIFY(second.watchLibrary(name));
        for (const auto &title : {QStringLiteral("First"), QStringLiteral("Second")}) {
            changed.clear();
            created = first.commit(name, rev(created), content(title));
            QCOMPARE(status(created), QStringLiteral("ok"));
            QTRY_VERIFY(!changed.isEmpty());
            QCOMPARE(changed.last().at(0).toString(), name);
            QCOMPARE(text(second.readSnapshot(name)), content(title));
        }
        changed.clear();
        QVERIFY(QFile::remove(path(name)));
        QTRY_VERIFY(!changed.isEmpty());
        QCOMPARE(status(second.readSnapshot(name)), QStringLiteral("missing"));
        changed.clear();
        created = first.create(name, content(QStringLiteral("Recreated")));
        QCOMPARE(status(created), QStringLiteral("ok"));
        QTRY_VERIFY(!changed.isEmpty());
        QCOMPARE(text(second.readSnapshot(name)), content(QStringLiteral("Recreated")));
        second.stopWatching();
        changed.clear();
        QCOMPARE(status(first.commit(name, rev(created), content(QStringLiteral("Stopped")))), QStringLiteral("ok"));
        QTest::qWait(150);
        QVERIFY(changed.isEmpty());
        QVERIFY(!second.watchLibrary(QStringLiteral("../escape")));
    }

    void qmlImport()
    {
        QQmlEngine engine;
        engine.addImportPath(QString::fromUtf8(qgetenv("KOPYPAST_TEST_QML_PATH")));
        QQmlComponent component(&engine);
        component.setData("import io.github.fooftilly.kopypast.fileio 1.0\nSharedLibrary {}", QUrl());
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        QVERIFY(qobject_cast<SharedLibrary *>(object.data()));
    }
};

QTEST_GUILESS_MAIN(SharedLibraryTest)
#include "tst_sharedlibrary.moc"
