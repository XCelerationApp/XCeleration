abstract interface class IGoogleSheetsService {
  Future<bool> signIn();
  Future<String?> createSheet({required String title});
  Future<bool> updateSheet({
    required String spreadsheetId,
    required List<List<dynamic>> data,
  });
  Future<Uri> getSheetUri(String spreadsheetId);
}
