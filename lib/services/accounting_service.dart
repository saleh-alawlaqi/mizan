import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

/// طريقة معالجة نصيب السائق من المصاريف المشتركة
enum SharedExpenseHandling {
  /// يُخصم من السائق ويُضاف لصافي المالك (المالك يسترجع ما دفعه نيابة عن السائق)
  addToOwner,

  /// يُخصم من السائق كمصروف تشغيلي عادي - لا يرجع للمالك (لأنه صُرف فعلاً)
  operatingExpense,

  /// العملية ملغاة بالكامل - لا يوجد توزيع
  cancelled,

  /// غير منطبق (مثلاً: لا يوجد مصروف مشترك في هذه العملية)
  notApplicable,
}

class AccountingInput {
  final double revenue;
  final double cityExpense;
  final double repairExpense;
  final double otherExpense;
  final double sharedExpense;
  final String contractType; // 'ratio' or 'fixed'
  final double ownerRatio;
  final double driverRatio;
  final double? monthlySalary;
  final SharedExpenseHandling sharedExpenseHandling;

  AccountingInput({
    required this.revenue,
    required this.cityExpense,
    required this.repairExpense,
    required this.otherExpense,
    required this.sharedExpense,
    required this.contractType,
    required this.ownerRatio,
    required this.driverRatio,
    this.monthlySalary,
    required this.sharedExpenseHandling,
  });
}

class CalculationStep {
  final String label;
  final Decimal value;
  final String? description;

  CalculationStep({required this.label, required this.value, this.description});
}

class AccountingResult {
  final Decimal revenue;
  final Decimal cityExpense;
  final Decimal repairExpense;
  final Decimal otherExpense;
  final Decimal totalOwnerExpenses;
  final Decimal distributableRevenue;
  final Decimal ownerShare;
  final Decimal driverShare;
  final Decimal sharedExpense;
  final Decimal driverSharedPortion;
  final Decimal ownerSharedPortion;
  final Decimal driverNet;
  final Decimal ownerNet;
  final List<CalculationStep> steps;
  final bool isFixedSalary;

  AccountingResult({
    required this.revenue,
    required this.cityExpense,
    required this.repairExpense,
    required this.otherExpense,
    required this.totalOwnerExpenses,
    required this.distributableRevenue,
    required this.ownerShare,
    required this.driverShare,
    required this.sharedExpense,
    required this.driverSharedPortion,
    required this.ownerSharedPortion,
    required this.driverNet,
    required this.ownerNet,
    required this.steps,
    required this.isFixedSalary,
  });
}

class AccountingService {
  static Decimal _d(num? value) {
    if (value == null) return Decimal.zero;
    return Decimal.parse(value.toString());
  }

  static AccountingResult calculate(AccountingInput input) {
    final revenue = _d(input.revenue);
    final cityExpense = _d(input.cityExpense);
    final repairExpense = _d(input.repairExpense);
    final otherExpense = _d(input.otherExpense);
    final sharedExpense = _d(input.sharedExpense);
    final isFixedSalary = input.contractType == 'fixed';

    final totalOwnerExpenses = cityExpense + repairExpense + otherExpense;
    final steps = <CalculationStep>[];

    steps.add(CalculationStep(
      label: 'الإيراد العام',
      value: revenue,
      description: 'الدفعة المستلمة من العميل',
    ));

    // ==================== عقد راتب ثابت ====================
    if (isFixedSalary) {
      final ownerNet = revenue - totalOwnerExpenses - sharedExpense;

      steps.add(CalculationStep(
        label: 'حصة المالك',
        value: revenue,
        description: 'السائق براتب ثابت - كل الإيراد للمالك',
      ));
      if (totalOwnerExpenses > Decimal.zero) {
        steps.add(CalculationStep(
          label: 'مصاريف المالك (مدينة + إصلاحات + أخرى)',
          value: -totalOwnerExpenses,
          description: 'تُخصم من المالك فقط',
        ));
      }
      if (sharedExpense > Decimal.zero) {
        steps.add(CalculationStep(
          label: 'المصاريف المشتركة',
          value: -sharedExpense,
          description: 'تُخصم بالكامل من المالك فقط',
        ));
      }
      steps.add(CalculationStep(
        label: 'صافي السائق',
        value: Decimal.zero,
        description: 'الراتب يُحسب شهرياً بشكل مستقل عند التصفية',
      ));
      steps.add(CalculationStep(label: 'صافي المالك', value: ownerNet));

      return AccountingResult(
        revenue: revenue,
        cityExpense: cityExpense,
        repairExpense: repairExpense,
        otherExpense: otherExpense,
        totalOwnerExpenses: totalOwnerExpenses,
        distributableRevenue: revenue,
        ownerShare: revenue,
        driverShare: Decimal.zero,
        sharedExpense: sharedExpense,
        driverSharedPortion: Decimal.zero,
        ownerSharedPortion: sharedExpense,
        driverNet: Decimal.zero,
        ownerNet: ownerNet,
        steps: steps,
        isFixedSalary: true,
      );
    }

    // ==================== عقد نسبة مئوية ====================
    final oRatio = _d(input.ownerRatio);
    final dRatio = _d(input.driverRatio);
    final totalRatio = oRatio + dRatio;

    if (input.sharedExpenseHandling == SharedExpenseHandling.cancelled) {
      steps.add(CalculationStep(
        label: 'العملية ملغاة',
        value: Decimal.zero,
        description: 'تم إلغاء العملية - لا توزيع',
      ));
      return AccountingResult(
        revenue: revenue,
        cityExpense: cityExpense,
        repairExpense: repairExpense,
        otherExpense: otherExpense,
        totalOwnerExpenses: totalOwnerExpenses,
        distributableRevenue: revenue,
        ownerShare: Decimal.zero,
        driverShare: Decimal.zero,
        sharedExpense: sharedExpense,
        driverSharedPortion: Decimal.zero,
        ownerSharedPortion: Decimal.zero,
        driverNet: Decimal.zero,
        ownerNet: Decimal.zero,
        steps: steps,
        isFixedSalary: false,
      );
    }

    Decimal ownerShare = Decimal.zero;
    Decimal driverShare = Decimal.zero;
    Decimal driverSharedPortion = Decimal.zero;
    Decimal ownerSharedPortion = Decimal.zero;

    if (totalRatio != Decimal.zero) {
      final double revDouble = double.tryParse(revenue.toString()) ?? 0.0;
      final double oRatioDouble = input.ownerRatio;
      final double dRatioDouble = input.driverRatio;
      final double totalRatioDouble = oRatioDouble + dRatioDouble;
      final double sharedDouble =
          double.tryParse(sharedExpense.toString()) ?? 0.0;

      if (totalRatioDouble > 0) {
        final oShareVal = (revDouble * oRatioDouble) / totalRatioDouble;
        final dShareVal = (revDouble * dRatioDouble) / totalRatioDouble;
        ownerShare = _d(double.tryParse(oShareVal.toStringAsFixed(4)) ?? 0.0);
        driverShare = _d(double.tryParse(dShareVal.toStringAsFixed(4)) ?? 0.0);

        final dPortionVal = (sharedDouble * dRatioDouble) / totalRatioDouble;
        final oPortionVal = (sharedDouble * oRatioDouble) / totalRatioDouble;
        driverSharedPortion =
            _d(double.tryParse(dPortionVal.toStringAsFixed(4)) ?? 0.0);
        ownerSharedPortion =
            _d(double.tryParse(oPortionVal.toStringAsFixed(4)) ?? 0.0);
      }
    }

    Decimal driverNet = Decimal.zero;
    Decimal ownerNet = Decimal.zero;

    steps.add(CalculationStep(
      label: 'توزيع الإيراد (نسبة)',
      value: revenue,
      description: 'المالك $oRatio : السائق $dRatio',
    ));
    steps.add(CalculationStep(label: 'حصة المالك', value: ownerShare));
    steps.add(CalculationStep(label: 'حصة السائق', value: driverShare));

    if (input.sharedExpenseHandling == SharedExpenseHandling.addToOwner) {
      driverNet = driverShare - driverSharedPortion;
      ownerNet = ownerShare + driverSharedPortion - totalOwnerExpenses;

      if (sharedExpense > Decimal.zero) {
        steps.add(CalculationStep(
          label: 'نصيب السائق من المصاريف المشتركة (خصم)',
          value: -driverSharedPortion,
          description: 'يُخصم من السائق',
        ));
        steps.add(CalculationStep(
          label: 'إضافة نصيب السائق للمالك',
          value: driverSharedPortion,
          description: 'المالك يسترجع ما دفعه نيابة عن السائق',
        ));
      }
    } else {
      driverNet = driverShare - driverSharedPortion;
      ownerNet = ownerShare - ownerSharedPortion - totalOwnerExpenses;

      if (sharedExpense > Decimal.zero) {
        steps.add(CalculationStep(
          label: 'نصيب السائق من المصاريف المشتركة',
          value: -driverSharedPortion,
          description: 'يُخصم من السائق كمصروف نهائي',
        ));
        steps.add(CalculationStep(
          label: 'نصيب المالك من المصاريف المشتركة',
          value: -ownerSharedPortion,
          description: 'يُخصم من المالك كمصروف نهائي',
        ));
      }
    }

    if (totalOwnerExpenses > Decimal.zero) {
      steps.add(CalculationStep(
        label: 'مصاريف المالك (مدينة + إصلاحات + أخرى)',
        value: -totalOwnerExpenses,
        description: 'تُخصم من المالك فقط',
      ));
    }

    steps.add(CalculationStep(label: 'صافي السائق', value: driverNet));
    steps.add(CalculationStep(label: 'صافي المالك', value: ownerNet));

    return AccountingResult(
      revenue: revenue,
      cityExpense: cityExpense,
      repairExpense: repairExpense,
      otherExpense: otherExpense,
      totalOwnerExpenses: totalOwnerExpenses,
      distributableRevenue: revenue,
      ownerShare: ownerShare,
      driverShare: driverShare,
      sharedExpense: sharedExpense,
      driverSharedPortion: driverSharedPortion,
      ownerSharedPortion: ownerSharedPortion,
      driverNet: driverNet,
      ownerNet: ownerNet,
      steps: steps,
      isFixedSalary: false,
    );
  }

  static String formatCurrency(Decimal value, {String currency = 'ر.س'}) {
    return '${value.toStringAsFixed(2)} $currency';
  }

  static double toNumber(Decimal value) {
    return double.tryParse(value.toStringAsFixed(2)) ?? 0.0;
  }

  /// نسبة التحصيل والمبلغ المتبقي لمشروع (يُستخدم مع مستخلصات المشاريع)
  static ({double remaining, double collectionRate}) calculateCollectionStatus(
    double received,
    double? expected,
  ) {
    final r = _d(received);
    final e = _d(expected);
    if (e == Decimal.zero) return (remaining: 0.0, collectionRate: 0.0);
    final remaining = e - r;

    final double rDouble = double.tryParse(r.toString()) ?? 0.0;
    final double eDouble = double.tryParse(e.toString()) ?? 1.0;
    final double rateDouble = (eDouble == 0) ? 0.0 : (rDouble / eDouble) * 100;

    return (
      remaining: toNumber(remaining),
      collectionRate: double.tryParse(rateDouble.toStringAsFixed(2)) ?? 0.0,
    );
  }
}
