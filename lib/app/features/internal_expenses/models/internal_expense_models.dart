// Modelos de Gastos internos. El servidor decide estados, etiquetas y alertas de color; aquí solo se leen.

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String? _str(dynamic v) => v == null ? null : '$v';
List<Map<String, dynamic>> _list(dynamic v) =>
    (v as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

/// Alerta de color del renglón: 'danger' (vencido / vence hoy) o 'warning' (próximo a vencer).
class ExpenseItem {
  final int id;
  final String name;
  final String? category;
  final String? supplierName;
  final String? responsible;
  final String periodicity;
  final double estimatedAmount;
  final String currencyCode;
  final String status;
  final String stateKey;
  final String stateLabel;
  final String? alert;
  final String? nextDueOn;
  final int? nextPeriodId;
  final double? nextAmount;
  final bool canPay;
  final String? payWarning;

  const ExpenseItem({
    required this.id,
    required this.name,
    this.category,
    this.supplierName,
    this.responsible,
    required this.periodicity,
    required this.estimatedAmount,
    required this.currencyCode,
    required this.status,
    required this.stateKey,
    required this.stateLabel,
    this.alert,
    this.nextDueOn,
    this.nextPeriodId,
    this.nextAmount,
    required this.canPay,
    this.payWarning,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> j) => ExpenseItem(
        id: _int(j['id']),
        name: '${j['name']}',
        category: _str(j['category']),
        supplierName: _str(j['supplier_name']),
        responsible: _str(j['responsible']),
        periodicity: '${j['periodicity'] ?? ''}',
        estimatedAmount: _num(j['estimated_amount']),
        currencyCode: '${j['currency_code']}',
        status: '${j['status']}',
        stateKey: '${j['state_key']}',
        stateLabel: '${j['state_label']}',
        alert: _str(j['alert']),
        nextDueOn: _str(j['next_due_on']),
        nextPeriodId: j['next_period_id'] == null ? null : _int(j['next_period_id']),
        nextAmount: j['next_amount'] == null ? null : _num(j['next_amount']),
        canPay: j['can_pay'] == true,
        payWarning: _str(j['pay_warning']),
      );
}

class ExpensePage {
  final List<ExpenseItem> items;
  final int currentPage;
  final int lastPage;

  const ExpensePage({required this.items, required this.currentPage, required this.lastPage});

  bool get hasMore => currentPage < lastPage;
}

class CurrencyAmount {
  final String currency;
  final int count;
  final double amount;

  const CurrencyAmount({required this.currency, required this.count, required this.amount});

  factory CurrencyAmount.fromJson(Map<String, dynamic> j) =>
      CurrencyAmount(currency: '${j['currency']}', count: _int(j['count']), amount: _num(j['amount']));
}

class MonthTotals {
  final String month; // AAAA-MM
  final List<CurrencyAmount> byCurrency;

  const MonthTotals({required this.month, required this.byCurrency});
}

class ExpenseSummary {
  final List<CurrencyAmount> dueSoon;
  final List<CurrencyAmount> overdue;
  final List<CurrencyAmount> pendingTotal;
  final List<CurrencyAmount> paidThisMonth;
  final List<MonthTotals> upcomingByMonth;

  const ExpenseSummary({
    required this.dueSoon,
    required this.overdue,
    required this.pendingTotal,
    required this.paidThisMonth,
    required this.upcomingByMonth,
  });

  factory ExpenseSummary.fromJson(Map<String, dynamic> j) {
    List<CurrencyAmount> amounts(dynamic v) => _list(v).map(CurrencyAmount.fromJson).toList();

    return ExpenseSummary(
      dueSoon: amounts(j['due_soon']),
      overdue: amounts(j['overdue']),
      pendingTotal: amounts(j['pending_total']),
      paidThisMonth: amounts(j['paid_this_month']),
      upcomingByMonth: _list(j['upcoming_by_month'])
          .map((m) => MonthTotals(month: '${m['month']}', byCurrency: amounts(m['by_currency'])))
          .toList(),
    );
  }
}

class Option {
  final String value;
  final String label;

  const Option(this.value, this.label);
}

class ExpenseFormData {
  final List<Option> categories;
  final List<Option> currencies;
  final List<Option> users;
  final List<Option> paymentMethods;
  final List<Option> frequencies;
  final List<Option> channels;

  const ExpenseFormData({
    required this.categories,
    required this.currencies,
    required this.users,
    required this.paymentMethods,
    required this.frequencies,
    required this.channels,
  });

  static const empty = ExpenseFormData(
    categories: [], currencies: [], users: [], paymentMethods: [], frequencies: [], channels: [],
  );

  factory ExpenseFormData.fromJson(Map<String, dynamic> j) {
    List<Option> opts(dynamic v, String value, String label) =>
        _list(v).map((e) => Option('${e[value]}', '${e[label]}')).toList();

    final freq = (j['frequencies'] as Map? ?? const {}).entries.map((e) => Option('${e.key}', '${e.value}')).toList();

    return ExpenseFormData(
      categories: opts(j['categories'], 'id', 'name'),
      currencies: opts(j['currencies'], 'code', 'code'),
      users: opts(j['users'], 'id', 'name'),
      paymentMethods: opts(j['payment_methods'], 'id', 'name'),
      frequencies: freq,
      channels: opts(j['channels'], 'key', 'label'),
    );
  }
}

class ReminderRule {
  final int daysBefore;
  final int? repeatEveryDays;

  const ReminderRule(this.daysBefore, {this.repeatEveryDays});

  factory ReminderRule.fromJson(Map<String, dynamic> j) => ReminderRule(
        _int(j['days_before']),
        repeatEveryDays: j['repeat_every_days'] == null ? null : _int(j['repeat_every_days']),
      );
}

/// Configuración completa del gasto (sirve también para precargar el formulario de edición).
class ExpenseConfig {
  final int id;
  final String name;
  final String? description;
  final int? categoryId;
  final String? category;
  final String? supplierName;
  final double estimatedAmount;
  final String currencyCode;
  final String kind;
  final String? frequency;
  final int? intervalDays;
  final List<int> semimonthlyDays;
  final String startsOn;
  final String firstDueOn;
  final String? endsOn;
  final int? responsibleUserId;
  final String? responsible;
  final String? createdBy;
  final String? createdAt;
  final String periodicity;
  final String status;
  final String? notes;
  final List<ReminderRule> reminderRules;
  final List<String> reminderChannels;

  const ExpenseConfig({
    required this.id,
    required this.name,
    this.description,
    this.categoryId,
    this.category,
    this.supplierName,
    required this.estimatedAmount,
    required this.currencyCode,
    required this.kind,
    this.frequency,
    this.intervalDays,
    required this.semimonthlyDays,
    required this.startsOn,
    required this.firstDueOn,
    this.endsOn,
    this.responsibleUserId,
    this.responsible,
    this.createdBy,
    this.createdAt,
    required this.periodicity,
    required this.status,
    this.notes,
    required this.reminderRules,
    required this.reminderChannels,
  });

  bool get isRecurring => kind == 'recurring';

  factory ExpenseConfig.fromJson(Map<String, dynamic> j) => ExpenseConfig(
        id: _int(j['id']),
        name: '${j['name']}',
        description: _str(j['description']),
        categoryId: j['category_id'] == null ? null : _int(j['category_id']),
        category: _str(j['category']),
        supplierName: _str(j['supplier_name']),
        estimatedAmount: _num(j['estimated_amount']),
        currencyCode: '${j['currency_code']}',
        kind: '${j['kind']}',
        frequency: _str(j['frequency']),
        intervalDays: j['interval_days'] == null ? null : _int(j['interval_days']),
        semimonthlyDays: (j['semimonthly_days'] as List? ?? const []).map(_int).toList(),
        startsOn: '${j['starts_on']}',
        firstDueOn: '${j['first_due_on']}',
        endsOn: _str(j['ends_on']),
        responsibleUserId: j['responsible_user_id'] == null ? null : _int(j['responsible_user_id']),
        responsible: _str(j['responsible']),
        createdBy: _str(j['created_by']),
        createdAt: _str(j['created_at']),
        periodicity: '${j['periodicity'] ?? ''}',
        status: '${j['status']}',
        notes: _str(j['notes']),
        reminderRules: _list(j['reminder_rules']).map(ReminderRule.fromJson).toList(),
        reminderChannels: (j['reminder_channels'] as List? ?? const []).map((e) => '$e').toList(),
      );
}

class Receipt {
  final String uuid;
  final String name;

  const Receipt(this.uuid, this.name);
}

class PaymentInfo {
  final double amount;
  final String paidOn;
  final String? reference;
  final String? method;
  final List<Receipt> receipts;

  const PaymentInfo({required this.amount, required this.paidOn, this.reference, this.method, required this.receipts});

  factory PaymentInfo.fromJson(Map<String, dynamic> j) => PaymentInfo(
        amount: _num(j['amount']),
        paidOn: '${j['paid_on']}',
        reference: _str(j['reference']),
        method: _str(j['method']),
        receipts: _list(j['receipts']).map((r) => Receipt('${r['uuid']}', '${r['name']}')).toList(),
      );
}

class ExpensePeriod {
  final int id;
  final String dueOn;
  final double amount;
  final String currencyCode;
  final String stateKey;
  final String stateLabel;
  final String? alert;
  final bool canPay;
  final String? payWarning;
  final PaymentInfo? payment;

  const ExpensePeriod({
    required this.id,
    required this.dueOn,
    required this.amount,
    required this.currencyCode,
    required this.stateKey,
    required this.stateLabel,
    this.alert,
    required this.canPay,
    this.payWarning,
    this.payment,
  });

  factory ExpensePeriod.fromJson(Map<String, dynamic> j) => ExpensePeriod(
        id: _int(j['id']),
        dueOn: '${j['due_on']}',
        amount: _num(j['amount']),
        currencyCode: '${j['currency_code']}',
        stateKey: '${j['state_key']}',
        stateLabel: '${j['state_label']}',
        alert: _str(j['alert']),
        canPay: j['can_pay'] == true,
        payWarning: _str(j['pay_warning']),
        payment: j['payment'] == null ? null : PaymentInfo.fromJson(Map<String, dynamic>.from(j['payment'] as Map)),
      );
}

class ReminderLog {
  final String scheduledFor;
  final String dueOn;
  final String? recipient;
  final String channel;
  final String status;
  final String? processedAt;
  final int attempts;
  final String? lastError;

  const ReminderLog({
    required this.scheduledFor,
    required this.dueOn,
    this.recipient,
    required this.channel,
    required this.status,
    this.processedAt,
    required this.attempts,
    this.lastError,
  });

  factory ReminderLog.fromJson(Map<String, dynamic> j) => ReminderLog(
        scheduledFor: '${j['scheduled_for']}',
        dueOn: '${j['due_on']}',
        recipient: _str(j['recipient']),
        channel: '${j['channel']}',
        status: '${j['status']}',
        processedAt: _str(j['processed_at']),
        attempts: _int(j['attempts']),
        lastError: _str(j['last_error']),
      );
}

class EventLog {
  final String? at;
  final String event;
  final String by;
  final String? notes;

  const EventLog({this.at, required this.event, required this.by, this.notes});

  factory EventLog.fromJson(Map<String, dynamic> j) =>
      EventLog(at: _str(j['at']), event: '${j['event']}', by: '${j['by']}', notes: _str(j['notes']));
}

class ExpenseDetail {
  final ExpenseConfig expense;
  final List<ExpensePeriod> periods;
  final List<ReminderLog> reminders;
  final List<EventLog> events;

  const ExpenseDetail({required this.expense, required this.periods, required this.reminders, required this.events});

  factory ExpenseDetail.fromJson(Map<String, dynamic> j) => ExpenseDetail(
        expense: ExpenseConfig.fromJson(Map<String, dynamic>.from(j['expense'] as Map)),
        periods: _list(j['periods']).map(ExpensePeriod.fromJson).toList(),
        reminders: _list(j['reminders']).map(ReminderLog.fromJson).toList(),
        events: _list(j['events']).map(EventLog.fromJson).toList(),
      );
}

class CalendarEntry {
  final int periodId;
  final int expenseId;
  final String name;
  final String dueOn;
  final double amount;
  final String currencyCode;
  final String stateKey;
  final String stateLabel;
  final String? alert;

  const CalendarEntry({
    required this.periodId,
    required this.expenseId,
    required this.name,
    required this.dueOn,
    required this.amount,
    required this.currencyCode,
    required this.stateKey,
    required this.stateLabel,
    this.alert,
  });

  factory CalendarEntry.fromJson(Map<String, dynamic> j) => CalendarEntry(
        periodId: _int(j['period_id']),
        expenseId: _int(j['expense_id']),
        name: '${j['name']}',
        dueOn: '${j['due_on']}',
        amount: _num(j['amount']),
        currencyCode: '${j['currency_code']}',
        stateKey: '${j['state_key']}',
        stateLabel: '${j['state_label']}',
        alert: _str(j['alert']),
      );
}
