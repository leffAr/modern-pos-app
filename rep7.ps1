
$content = Get-Content -Raw lib\features\dashboard\presentation\dashboard_screen.dart
$content = $content -replace "late Stream<List<Transaction>> _transactionsStream;", "late Stream<List<drift.TypedResult>> _dashboardDataStream;"
$content = $content -replace "_transactionsStream = .*watch\(\);", "_dashboardDataStream = (appDb.select(appDb.transactions).join([ drift.leftOuterJoin(appDb.payments, appDb.payments.transactionId.equalsExp(appDb.transactions.id)) ])..orderBy([drift.OrderingTerm(expression: appDb.transactions.createdAt, mode: drift.OrderingMode.desc)])).watch();"
$content = $content -replace "StreamBuilder<List<Transaction>>", "StreamBuilder<List<drift.TypedResult>>"
$content = $content -replace "stream: _transactionsStream,", "stream: _dashboardDataStream,"
Set-Content -Path lib\features\dashboard\presentation\dashboard_screen.dart -Value $content
