import 'package:flutter/material.dart';
import 'bib_records_provider.dart';
import '../../../../../utils/enums.dart';
import 'package:provider/provider.dart';
import '../../../../../core/services/device_connection_service.dart';

class BibNumberModel {
  final List<dynamic> runners;
  final Map<DeviceName, Map<String, dynamic>> otherDevices;
  
  BibNumberModel({
    List<dynamic>? initialRunners,
    Map<DeviceName, Map<String, dynamic>>? initialOtherDevices,
  }) : 
    runners = initialRunners ?? [],
    otherDevices = initialOtherDevices ?? DeviceConnectionService.createOtherDeviceList(
      DeviceName.bibRecorder,
      DeviceType.browserDevice,
    );

  bool get hasRunners => runners.isNotEmpty;

  // Helper for checking if a record exists with flag
  bool hasRecordsWithFlag(BuildContext context, String flagName) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    return provider.bibRecords.any((bib) => bib.flags[flagName] == true);
  }
  
  // Helper to check if we have any non-empty bib numbers
  bool hasNonEmptyBibNumbers(BuildContext context) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    return provider.bibRecords.any((record) => record.bibNumber.isNotEmpty);
  }
  
  // Helper to count non-empty bib numbers
  int countNonEmptyBibNumbers(BuildContext context) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    return provider.bibRecords.where((bib) => bib.bibNumber.isNotEmpty).length;
  }
  
  // Helper to count empty bib numbers
  int countEmptyBibNumbers(BuildContext context) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    return provider.bibRecords.where((bib) => bib.bibNumber.isEmpty).length;
  }
  
  // Helper to count duplicate bib numbers
  int countDuplicateBibNumbers(BuildContext context) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    return provider.bibRecords.where((bib) => bib.flags['duplicate_bib_number'] == true).length;
  }
  
  // Helper to count unknown bib numbers
  int countUnknownBibNumbers(BuildContext context) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    return provider.bibRecords.where((bib) => bib.flags['not_in_database'] == true).length;
  }
}
