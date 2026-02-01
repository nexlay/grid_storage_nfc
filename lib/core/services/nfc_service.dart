import 'dart:async'; // Required for Completer
import 'dart:convert';
import 'dart:io'; // Required for Platform check
import 'dart:typed_data';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

class NfcService {
  Future<void> startSession(Function(String) onDiscovered) async {
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
    final Completer<void> completer = Completer<void>();

    bool isAvailable = await NfcManager.instance.checkAvailability() !=
        NfcAvailability.disabled;
    if (!isAvailable) {
      return Future.error("NFC is not enabled");
    }

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            var ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              await NfcManager.instance
                  .stopSession(errorMessageIos: 'Tag is not writable');
              if (!completer.isCompleted) {
                completer.completeError('Tag is not writable');
              }
              return;
            }

            NdefRecord record = _createTextRecord(payload);
            NdefMessage message = NdefMessage(records: [record]);

            await ndef.write(message: message);

            if (Platform.isIOS) {
              await NfcManager.instance
                  .stopSession(alertMessageIos: 'Success!');
            } else {
              await NfcManager.instance.stopSession();
            }

            if (!completer.isCompleted) completer.complete();
          } catch (e) {
            await NfcManager.instance
                .stopSession(errorMessageIos: e.toString());
            if (!completer.isCompleted) completer.completeError(e);
          }
        },
        // Removed the invalid onError parameter
      );
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }

    return completer.future;
  }

  /// Helper to create an NDEF Text Record manually
  NdefRecord _createTextRecord(String text) {
    final languageCode = utf8.encode('en');
    final textBytes = utf8.encode(text);
    final statusByte = languageCode.length;
    final payload = <int>[statusByte, ...languageCode, ...textBytes];

    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x54]),
      identifier: Uint8List.fromList([]),
      payload: Uint8List.fromList(payload),
    );
  }
}
