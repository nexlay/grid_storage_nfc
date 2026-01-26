import 'dart:convert';
import 'dart:typed_data';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

class NfcService {
  Future<void> startSession(Function(String) onDiscovered) async {
    // Check availability
    bool isAvailable = await NfcManager.instance.checkAvailability() !=
        NfcAvailability.disabled;
    if (!isAvailable) return;

    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (NfcTag tag) async {
        final ndef = Ndef.from(tag);

        if (ndef != null && ndef.cachedMessage != null) {
          if (ndef.cachedMessage!.records.isNotEmpty) {
            final record = ndef.cachedMessage!.records.first;
            final payload = String.fromCharCodes(record.payload);

            // Simple cleanup
            String cleanPayload = payload;
            if (payload.length > 3) {
              cleanPayload = payload.substring(3);
            }
            onDiscovered(cleanPayload);
          }
        }
      },
    );
  }

  Future<void> stopSession() async {
    await NfcManager.instance.stopSession();
  }

  Future<void> writeTag(String payload) async {
    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (NfcTag tag) async {
        var ndef = Ndef.from(tag);

        if (ndef == null || !ndef.isWritable) {
          await NfcManager.instance.stopSession();
          return;
        }

        // FIX: Create Text Record manually since .createText is missing
        NdefRecord record = _createTextRecord(payload);

        // FIX: Use named parameter 'records'
        NdefMessage message = NdefMessage(records: [record]);

        try {
          // FIX: write takes positional argument
          await ndef.write(message: message);
          await NfcManager.instance.stopSession();
        } catch (e) {
          await NfcManager.instance.stopSession();
        }
      },
    );
  }

  /// Helper to create an NDEF Text Record manually
  NdefRecord _createTextRecord(String text) {
    final languageCode = utf8.encode('en');
    final textBytes = utf8.encode(text);

    // Status byte: Bit 7 = 0 (UTF-8), Bits 0-5 = language code length
    final statusByte = languageCode.length;

    final payload = <int>[statusByte, ...languageCode, ...textBytes];

    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x54]), // 'T'
      identifier: Uint8List.fromList([]),
      payload: Uint8List.fromList(payload),
    );
  }
}
