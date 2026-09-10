import '../services/accounting_service.dart';

/// يحوّل قيمة enum إلى النص المخزّن في قاعدة البيانات
String sharedExpenseHandlingToDb(SharedExpenseHandling handling) {
  switch (handling) {
    case SharedExpenseHandling.addToOwner:
      return 'add_to_owner';
    case SharedExpenseHandling.operatingExpense:
      return 'operating_expense';
    case SharedExpenseHandling.cancelled:
      return 'cancelled';
    case SharedExpenseHandling.notApplicable:
      return 'not_applicable';
  }
}

SharedExpenseHandling sharedExpenseHandlingFromDb(String? value) {
  switch (value) {
    case 'add_to_owner':
      return SharedExpenseHandling.addToOwner;
    case 'operating_expense':
      return SharedExpenseHandling.operatingExpense;
    case 'cancelled':
      return SharedExpenseHandling.cancelled;
    default:
      return SharedExpenseHandling.notApplicable;
  }
}

class OperationModel {
  final String? id;
  final String? date;
  final String equipmentId;
  final String equipmentName;
  final String driverId;
  final String driverName;
  final String projectId;
  final String projectName;
  final String clientName;

  final double revenue;
  final double cityExpense;
  final double repairExpense;
  final double otherExpense;
  final double sharedExpense;

  final String contractType; // 'ratio' or 'fixed'
  final double ownerRatio;
  final double driverRatio;
  final SharedExpenseHandling sharedExpenseHandling;

  // نتائج الحساب (تم جعلها اختيارية بقيمة افتراضية 0.0 لتجنب أخطاء الإنشاء)
  final double ownerShare;
  final double driverShare;
  final double driverSharedPortion;
  final double ownerSharedPortion;
  final double totalExpenses;
  final double driverNet;
  final double ownerNet;

  final DateTime? createdAt;

  OperationModel({
    this.id,
    this.date,
    required this.equipmentId,
    this.equipmentName = '',
    required this.driverId,
    this.driverName = '',
    required this.projectId,
    this.projectName = '',
    this.clientName = '',
    required this.revenue,
    required this.cityExpense,
    required this.repairExpense,
    required this.otherExpense,
    required this.sharedExpense,
    required this.contractType,
    required this.ownerRatio,
    required this.driverRatio,
    required this.sharedExpenseHandling,
    this.ownerShare = 0.0,
    this.driverShare = 0.0,
    this.driverSharedPortion = 0.0,
    this.ownerSharedPortion = 0.0,
    this.totalExpenses = 0.0,
    this.driverNet = 0.0,
    this.ownerNet = 0.0,
    this.createdAt,
  });

  /// ينشئ عملية جديدة مع تنفيذ الحساب فوراً عبر AccountingService
  factory OperationModel.calculate({
    String? date,
    required String equipmentId,
    String equipmentName = '',
    required String driverId,
    String driverName = '',
    required String projectId,
    String projectName = '',
    String clientName = '',
    required double revenue,
    required double cityExpense,
    required double repairExpense,
    required double otherExpense,
    required double sharedExpense,
    required String contractType,
    required double ownerRatio,
    required double driverRatio,
    required SharedExpenseHandling sharedExpenseHandling,
  }) {
    final result = AccountingService.calculate(AccountingInput(
      revenue: revenue,
      cityExpense: cityExpense,
      repairExpense: repairExpense,
      otherExpense: otherExpense,
      sharedExpense: sharedExpense,
      contractType: contractType,
      ownerRatio: ownerRatio,
      driverRatio: driverRatio,
      sharedExpenseHandling: sharedExpenseHandling,
    ));

    return OperationModel(
      date: date,
      equipmentId: equipmentId,
      equipmentName: equipmentName,
      driverId: driverId,
      driverName: driverName,
      projectId: projectId,
      projectName: projectName,
      clientName: clientName,
      revenue: revenue,
      cityExpense: cityExpense,
      repairExpense: repairExpense,
      otherExpense: otherExpense,
      sharedExpense: sharedExpense,
      contractType: contractType,
      ownerRatio: ownerRatio,
      driverRatio: driverRatio,
      sharedExpenseHandling: sharedExpenseHandling,
      ownerShare: AccountingService.toNumber(result.ownerShare),
      driverShare: AccountingService.toNumber(result.driverShare),
      driverSharedPortion:
          AccountingService.toNumber(result.driverSharedPortion),
      ownerSharedPortion: AccountingService.toNumber(result.ownerSharedPortion),
      totalExpenses: AccountingService.toNumber(result.totalOwnerExpenses),
      driverNet: AccountingService.toNumber(result.driverNet),
      ownerNet: AccountingService.toNumber(result.ownerNet),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'equipment_id': equipmentId,
      'equipment_name': equipmentName,
      'driver_id': driverId,
      'driver_name': driverName,
      'project_id': projectId,
      'project_name': projectName,
      'client_name': clientName,
      'revenue': revenue,
      'city_expense': cityExpense,
      'repair_expense': repairExpense,
      'other_expense': otherExpense,
      'shared_expense': sharedExpense,
      'contract_type': contractType,
      'owner_ratio': ownerRatio,
      'driver_ratio': driverRatio,
      'shared_expense_handling':
          sharedExpenseHandlingToDb(sharedExpenseHandling),
      'owner_share': ownerShare,
      'driver_share': driverShare,
      'driver_shared_portion': driverSharedPortion,
      'owner_shared_portion': ownerSharedPortion,
      'total_expenses': totalExpenses,
      'driver_net': driverNet,
      'owner_net': ownerNet,
    };
  }

  factory OperationModel.fromJson(Map<String, dynamic> json) {
    return OperationModel(
      id: json['id']?.toString(),
      date: json['date']?.toString(),
      equipmentId: json['equipment_id']?.toString() ?? '',
      equipmentName: json['equipment_name']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      driverName: json['driver_name']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      projectName: json['project_name']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      cityExpense: (json['city_expense'] as num?)?.toDouble() ?? 0.0,
      repairExpense: (json['repair_expense'] as num?)?.toDouble() ?? 0.0,
      otherExpense: (json['other_expense'] as num?)?.toDouble() ?? 0.0,
      sharedExpense: (json['shared_expense'] as num?)?.toDouble() ?? 0.0,
      contractType: json['contract_type']?.toString() ?? 'ratio',
      ownerRatio: (json['owner_ratio'] as num?)?.toDouble() ?? 2.0,
      driverRatio: (json['driver_ratio'] as num?)?.toDouble() ?? 1.0,
      sharedExpenseHandling: sharedExpenseHandlingFromDb(
        json['shared_expense_handling']?.toString(),
      ),
      ownerShare: (json['owner_share'] as num?)?.toDouble() ?? 0.0,
      driverShare: (json['driver_share'] as num?)?.toDouble() ?? 0.0,
      driverSharedPortion:
          (json['driver_shared_portion'] as num?)?.toDouble() ?? 0.0,
      ownerSharedPortion:
          (json['owner_shared_portion'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0.0,
      driverNet: (json['driver_net'] as num?)?.toDouble() ?? 0.0,
      ownerNet: (json['owner_net'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
