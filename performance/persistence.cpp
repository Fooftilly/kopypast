// SPDX-License-Identifier: GPL-3.0-or-later
#include <KConfig>
#include <KConfigGroup>
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QTextStream>
#include <algorithm>
#include <vector>

namespace {
QJsonObject stats(std::vector<qint64> samples)
{
    std::sort(samples.begin(), samples.end());
    return {{QStringLiteral("median_ms"), samples[samples.size()/2]},
            {QStringLiteral("p95_ms"), samples.back()},
            {QStringLiteral("samples"), static_cast<int>(samples.size())}};
}

QString fixture(int size)
{
    QJsonArray records;
    const auto body = QStringLiteral("Example procedure:\n  inspect the configuration and review the results.\nUnicode: čćž 日本語\n").repeated(4);
    for (int i=0; i<size; ++i)
        records.append(QJsonObject{
            {QStringLiteral("id"), QStringLiteral("benchmark-%1").arg(i)},
            {QStringLiteral("title"), QStringLiteral("Snippet %1").arg(i)},
            {QStringLiteral("text"), body + QStringLiteral("\nIdentifier: %1").arg(i)},
            {QStringLiteral("usageCount"), i%17},
            {QStringLiteral("favorite"), i%20 == 0}});
    return QString::fromUtf8(QJsonDocument(records).toJson(QJsonDocument::Compact));
}
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QTemporaryDir dir;
    if (!dir.isValid())
        return 1;
    QTextStream output(stdout);
    for (int count : {100, 1000, 10000}) {
        const auto raw = fixture(count);
        qsizetype failedReads = 0;
        qsizetype firstFailedReadLength = -1;
        qint64 fileBytes = 0;
        std::vector<qint64> writes, reads;
        for (int iteration=0; iteration<9; ++iteration) {
            // Isolate each sample: never rewrite a file after a failed read.
            const auto file = dir.filePath(QStringLiteral("applets-%1-%2rc").arg(count).arg(iteration));
            // Vary the value to force a real write, not a no-op sync.
            const QString value = raw + QString(iteration+1, QChar(' '));
            QElapsedTimer timer;
            timer.start();
            {
                KConfig config(file, KConfig::SimpleConfig);
                KConfigGroup group = config.group("Containments").group("1")
                    .group("Applets").group("2").group("Configuration").group("Snippets");
                group.writeEntry("snippets", value);
                if (!config.sync())
                    return 2;
            }
            writes.push_back(timer.elapsed());
            timer.restart();
            {
                KConfig config(file, KConfig::SimpleConfig);
                const KConfigGroup group = config.group("Containments").group("1")
                    .group("Applets").group("2").group("Configuration").group("Snippets");
                const auto recovered = group.readEntry("snippets", QString());
                if (recovered != value) {
                    ++failedReads;
                    if (firstFailedReadLength < 0)
                        firstFailedReadLength = recovered.size();
                    // Fail any unexpected mismatch in the supported-size fixtures.
                    // The large fixture is a capability probe, not a supported limit.
                    if (count <= 1000)
                        return 3;
                }
            }
            reads.push_back(timer.elapsed());
            fileBytes = std::max(fileBytes, QFileInfo(file).size());
        }
        const QJsonObject result{{QStringLiteral("records"), count},
                                 {QStringLiteral("utf16_code_units"), raw.size()},
                                 {QStringLiteral("file_bytes"), fileBytes},
                                 {QStringLiteral("round_trip_ok"), failedReads == 0},
                                 {QStringLiteral("failed_reads"), failedReads},
                                 {QStringLiteral("first_failed_read_length"), firstFailedReadLength},
                                 {QStringLiteral("write_sync"), stats(writes)},
                                 {QStringLiteral("read_attempt"), stats(reads)}};
        output << "KOPYPAST_KCONFIG_BENCHMARK " << QJsonDocument(result).toJson(QJsonDocument::Compact) << '\n';
        output.flush();
    }
}
