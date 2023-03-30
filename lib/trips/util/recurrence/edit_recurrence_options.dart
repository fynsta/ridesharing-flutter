import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:rrule/rrule.dart';

import '../../../managers/locale_manager.dart';
import '../../../util/fields/text_with_fields.dart';
import 'recurrence.dart';
import 'recurrence_options_indicator.dart';
import 'week_day.dart';

class EditRecurrenceOptions extends StatefulWidget {
  final RecurrenceOptions recurrenceOptions;
  final List<RecurrenceEndChoice> predefinedEndChoices;
  final RecurrenceRule? originalRecurrenceRule;
  final bool showPreview;
  final void Function(bool expanded)? expansionCallback;

  const EditRecurrenceOptions({
    super.key,
    required this.recurrenceOptions,
    required this.predefinedEndChoices,
    this.originalRecurrenceRule,
    this.showPreview = true,
    this.expansionCallback,
  });

  @override
  State<EditRecurrenceOptions> createState() => EditRecurrenceOptionsState();
}

class EditRecurrenceOptionsState extends State<EditRecurrenceOptions> {
  late final RecurrenceOptions recurrenceOptions;
  late final RecurrenceRule originalRecurrenceRule;
  late List<RecurrenceEndChoice> predefinedEndChoices;

  final TextEditingController recurrenceIntervalSizeController = TextEditingController();
  final TextEditingController recurrenceIntervalTypeController = TextEditingController();

  // The current end choice from the dialog, only applied when valid
  late RecurrenceEndChoice dialogEndChoice;

  RecurrenceEndChoiceDate customEndDateChoice = RecurrenceEndChoiceDate(null, isCustom: true);
  final TextEditingController customEndDateController = TextEditingController();

  RecurrenceEndChoiceInterval customEndIntervalChoice =
      RecurrenceEndChoiceInterval(null, RecurrenceIntervalType.weeks, isCustom: true);
  final TextEditingController customEndIntervalSizeController = TextEditingController();
  final TextEditingController customEndIntervalTypeController = TextEditingController();

  RecurrenceEndChoiceOccurrence customEndOccurrenceChoice = RecurrenceEndChoiceOccurrence(null, isCustom: true);
  final TextEditingController customEndOccurrenceController = TextEditingController();

  final TextEditingController endChoiceController = TextEditingController();

  String? validationError;

  @override
  void initState() {
    super.initState();

    recurrenceOptions = widget.recurrenceOptions;
    originalRecurrenceRule = widget.originalRecurrenceRule ?? recurrenceOptions.recurrenceRule;
    predefinedEndChoices = widget.predefinedEndChoices;
  }

  @override
  void didChangeDependencies() {
    // This is here instead of initState because of the context
    recurrenceIntervalSizeController.text = recurrenceOptions.recurrenceIntervalSize.toString();
    // We prefill this field when it's not selected yet
    customEndIntervalTypeController.text =
        customEndIntervalChoice.intervalType?.getName(context, customEndIntervalChoice.intervalSize ?? 2) ?? '';

    endChoiceController.text = recurrenceOptions.endChoice.getName(context);
    setDialogEndChoice(recurrenceOptions.endChoice, setDialogValues: true);

    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();

    endChoiceController.dispose();
    recurrenceIntervalSizeController.dispose();
    recurrenceIntervalTypeController.dispose();
    customEndDateController.dispose();
    customEndIntervalSizeController.dispose();
    customEndIntervalTypeController.dispose();
    customEndOccurrenceController.dispose();
  }

  bool validateDialogEndChoice({bool createError = true}) {
    final String? error = dialogEndChoice.validate(context);
    if (createError || error == null) {
      validationError = error;
    }
    return validationError == null;
  }

  void setDialogEndChoice(RecurrenceEndChoice value, {bool setDialogValues = false}) {
    dialogEndChoice = value;

    if (setDialogValues && value.isCustom) {
      if (value is RecurrenceEndChoiceDate) {
        customEndDateChoice = value;
        if (value.date != null) customEndDateController.text = localeManager.formatDate(value.date!);
      } else if (value is RecurrenceEndChoiceInterval) {
        customEndIntervalChoice = value;
        if (value.intervalSize != null) customEndIntervalSizeController.text = value.intervalSize.toString();
        if (value.intervalType != null) {
          customEndIntervalTypeController.text = value.intervalType!.getName(
            context,
            value.intervalSize ?? 2,
          );
        }
      } else if (value is RecurrenceEndChoiceOccurrence) {
        customEndOccurrenceChoice = value;
        if (value.occurrences != null) customEndOccurrenceController.text = value.occurrences.toString();
      }
    }
  }

  void trySetEndChoiceFromDialog() {
    // If it is valid, we apply it
    if (dialogEndChoice.validate(context) == null) {
      setState(() {
        recurrenceOptions.endChoice = dialogEndChoice.copyWith();
        endChoiceController.text = recurrenceOptions.endChoice.getName(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        buildWeekDayPicker(),
        const SizedBox(height: 10),
        buildIntervalPicker(),
        const SizedBox(height: 10),
        buildUntilPicker(),
        if (recurrenceOptions.weekDays.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          buildIndicator(),
        ]
      ],
    );
  }

  Widget buildWeekDayPicker() {
    return WeekDayPicker(
      weekDays: <WeekDay>[...recurrenceOptions.weekDays],
      context: context,
      onChanged: (List<WeekDay> weekDays) => setState(() {
        recurrenceOptions.weekDays = weekDays;
      }),
    );
  }

  Widget buildIntervalPicker() {
    final Widget intervalSizeField = TextFormField(
      decoration: const InputDecoration(border: OutlineInputBorder()),
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
      controller: recurrenceIntervalSizeController,
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return S.of(context).recurrenceIntervalValidationIntervalNull;
        }
        if (int.tryParse(value) == 0) {
          return S.of(context).recurrenceIntervalValidationIntervalZero;
        }
        return null;
      },
      onChanged: (String value) {
        setState(() {
          final int? parsedValue = int.tryParse(value);
          if (parsedValue != null && parsedValue > 0) {
            recurrenceOptions.recurrenceIntervalSize = parsedValue;
          }
        });
      },
      key: const Key('intervalSizeField'),
    );

    return TextWithFields(
      S.of(context).recurrenceIntervalEveryWeeksPlaceholder(
            recurrenceOptions.recurrenceIntervalSize ?? 2,
            TextWithFields.placeholder,
          ),
      fields: <Widget>[SizedBox(width: 80, child: intervalSizeField)],
      separator: const SizedBox(width: 5),
      textStyle: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget buildUntilPicker() {
    return SizedBox(
      width: 200,
      child: TextFormField(
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onTap: () => showRecurrenceEndDialog(),
        readOnly: true,
        controller: endChoiceController,
        key: const Key('untilField'),
      ),
    );
  }

  Widget buildIndicator() {
    return RecurrenceOptionsIndicator(
      previousRule: originalRecurrenceRule,
      newRule: recurrenceOptions.recurrenceRule,
      showPreview: widget.showPreview,
      startedAt: recurrenceOptions.startedAt,
    );
  }

  Future<void> showRecurrenceEndDialog() async {
    await showDialog<RecurrenceEndChoice>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, void Function(VoidCallback) innerSetState) {
          void onChanged(RecurrenceEndChoice? value) {
            innerSetState(() {
              setDialogEndChoice(value!);
            });
          }

          return AlertDialog(
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ...List<RadioListTile<RecurrenceEndChoice>>.generate(
                    predefinedEndChoices.length + RecurrenceEndType.values.length,
                    (int index) {
                      if (index < predefinedEndChoices.length) {
                        final RecurrenceEndChoice recurringEndChoice = predefinedEndChoices[index];

                        return RadioListTile<RecurrenceEndChoice>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(recurringEndChoice.getName(context, short: true)),
                          value: recurringEndChoice,
                          groupValue: dialogEndChoice,
                          onChanged: onChanged,
                          key: Key('predefinedEndChoice$index'),
                        );
                      } else {
                        final RecurrenceEndType recurrenceEndType =
                            RecurrenceEndType.values[index - predefinedEndChoices.length];
                        final bool currentlySelected =
                            dialogEndChoice.type == recurrenceEndType && dialogEndChoice.isCustom;

                        RecurrenceEndChoice recurrenceEndChoiceCustom;
                        Widget content;

                        switch (recurrenceEndType) {
                          case RecurrenceEndType.date:
                            recurrenceEndChoiceCustom = customEndDateChoice;

                            final Widget datePicker = TextFormField(
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                hintText: S.of(context).formDate,
                              ),
                              readOnly: true,
                              enabled: currentlySelected,
                              onTap: () => showDatePicker(
                                context: context,
                                initialDate: customEndDateChoice.date ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                              ).then((DateTime? value) {
                                if (value != null) {
                                  innerSetState(() {
                                    customEndDateChoice.date = value;
                                    customEndDateController.text = localeManager.formatDate(value);
                                  });
                                }
                              }),
                              controller: customEndDateController,
                              key: const Key('customEndDateField'),
                            );

                            content = TextWithFields(
                              S.of(context).recurrenceEndDateChoice(TextWithFields.placeholder),
                              fields: <Widget>[Flexible(child: datePicker)],
                            );
                            break;
                          case RecurrenceEndType.interval:
                            recurrenceEndChoiceCustom = customEndIntervalChoice;

                            final Widget intervalSizeField = TextFormField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                // Default padding is EdgeInsets.fromLTRB(12, 24, 12, 16)
                                contentPadding: EdgeInsets.fromLTRB(6, 24, 12, 6),
                                hintText: 'x',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                              enabled: currentlySelected,
                              controller: customEndIntervalSizeController,
                              onChanged: (String value) {
                                innerSetState(() {
                                  customEndIntervalChoice.intervalSize = int.tryParse(value);
                                  customEndIntervalTypeController.text = customEndIntervalChoice.intervalType!.getName(
                                    context,
                                    customEndIntervalChoice.intervalSize ?? 2,
                                  );
                                });
                              },
                              key: const Key('customEndIntervalSizeField'),
                            );

                            final Widget intervalTypeField = PopupMenuButton<RecurrenceIntervalType>(
                              initialValue: customEndIntervalChoice.intervalType,
                              onSelected: (RecurrenceIntervalType value) => innerSetState(() {
                                customEndIntervalChoice.intervalType = value;
                                customEndIntervalTypeController.text =
                                    value.getName(context, customEndIntervalChoice.intervalSize ?? 2);
                              }),
                              enabled: currentlySelected,
                              itemBuilder: (BuildContext context) => RecurrenceIntervalType.values
                                  .map(
                                    (RecurrenceIntervalType intervalType) => PopupMenuItem<RecurrenceIntervalType>(
                                      value: intervalType,
                                      key: Key('customEndIntervalType${intervalType.name}'),
                                      child: Text(
                                        intervalType.getName(context, customEndIntervalChoice.intervalSize ?? 2),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              key: const Key('customEndIntervalTypeField'),
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    // Default padding is EdgeInsets.fromLTRB(12, 24, 12, 16)
                                    contentPadding: EdgeInsets.fromLTRB(6, 24, 12, 6),
                                    isDense: true,
                                  ),
                                  enabled: currentlySelected,
                                  readOnly: true,
                                  controller: customEndIntervalTypeController,
                                ),
                              ),
                            );

                            content = TextWithFields(
                              S.of(context).recurrenceEndIntervalChoice(TextWithFields.placeholder),
                              fields: <Widget>[
                                SizedBox(width: 45, child: intervalSizeField),
                                SizedBox(width: 80, child: intervalTypeField),
                              ],
                            );
                            break;
                          case RecurrenceEndType.occurrence:
                            recurrenceEndChoiceCustom = customEndOccurrenceChoice;

                            final Widget occurenceField = TextFormField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                // Default padding is EdgeInsets.fromLTRB(12, 24, 12, 16)
                                contentPadding: EdgeInsets.fromLTRB(6, 24, 12, 6),
                                hintText: 'y',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                              enabled: currentlySelected,
                              controller: customEndOccurrenceController,
                              onChanged: (String value) {
                                innerSetState(() {
                                  customEndOccurrenceChoice.occurrences = int.tryParse(value);
                                });
                              },
                              key: const Key('customEndOccurenceField'),
                            );

                            content = TextWithFields(
                              S.of(context).recurrenceEndOccurencesChoice(TextWithFields.placeholder),
                              fields: <Widget>[SizedBox(width: 45, child: occurenceField)],
                            );
                            break;
                        }

                        return RadioListTile<RecurrenceEndChoice>(
                          contentPadding: EdgeInsets.zero,
                          title: content,
                          value: recurrenceEndChoiceCustom,
                          groupValue: dialogEndChoice,
                          onChanged: onChanged,
                          key: Key('recurrenceEndChoice$index'),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  if (!validateDialogEndChoice(createError: false))
                    Text(
                      S.of(context).recurrenceEndError(validationError!),
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                      key: const Key('recurrenceEndError'),
                    ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                key: const Key('okButtonRecurrenceEndDialog'),
                child: Text(S.of(context).okay),
                onPressed: () {
                  innerSetState(() {
                    final bool valid = validateDialogEndChoice();
                    if (valid) {
                      Navigator.of(context).pop();
                    }
                  });
                },
              ),
            ],
          );
        },
      ),
    ).then((RecurrenceEndChoice? value) => trySetEndChoiceFromDialog());
  }
}
