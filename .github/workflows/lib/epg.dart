import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';
import 'package:xml/xml_events.dart';
import 'util.dart';

class EpgParseInput {
  final Uint8List bytes;
  final int offsetMin;
  const EpgParseInput(this.bytes, this.offsetMin);
}

class EpgParseResult {
  final List<Map<String, Object?>> channels;
  final List<Map<String, Object?>> progs;
  EpgParseResult(this.channels, this.progs);
}

String? _attr(XmlStartElementEvent e, String n) {
  for (final a in e.attributes) {
    if (a.name == n) return a.value;
  }
  return null;
}

/// XMLTV (düz ya da .gz) okur. 14 günlük pencere (-7 gün ... +7 gün) ve zaman kayması destekler.
EpgParseResult parseXmltvInput(EpgParseInput input) => parseXmltv(input.bytes, offsetMin: input.offsetMin);

EpgParseResult parseXmltv(Uint8List bytes, {int offsetMin = 0}) {
  var data = bytes;
  if (data.length > 2 && data[0] == 0x1f && data[1] == 0x8b) {
    data = Uint8List.fromList(gzip.decode(data));
  }
  final text = utf8.decode(data, allowMalformed: true);
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final from = now - 7 * 86400;
  final to = now + 7 * 86400;
  final offSec = offsetMin * 60;

  final chans = <Map<String, Object?>>[];
  final progs = <Map<String, Object?>>[];
  String? tag, chId, pCh, pTitle, pDesc;
  int? pStart, pStop;
  var inProg = false;

  void onStart(XmlStartElementEvent e) {
    if (e.name == 'channel') {
      chId = _attr(e, 'id')?.toLowerCase();
    } else if (e.name == 'programme') {
      inProg = true;
      pCh = _attr(e, 'channel')?.toLowerCase();
      final s = parseXmltvTime(_attr(e, 'start'));
      final st = parseXmltvTime(_attr(e, 'stop'));
      pStart = s != null ? s + offSec : null;
      pStop = st != null ? st + offSec : null;
      pTitle = null;
      pDesc = null;
    }
    tag = e.name;
  }

  void onEnd(String name) {
    if (name == 'programme') {
      if (inProg && pCh != null && pStart != null && pStop != null && pStop! > from && pStart! < to) {
        progs.add({'chan': pCh, 'start': pStart, 'stop': pStop, 'title': pTitle ?? '', 'descr': pDesc ?? ''});
      }
      inProg = false;
    } else if (name == 'channel') {
      chId = null;
    }
    tag = null;
  }

  void onText(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return;
    if (tag == 'display-name' && chId != null) {
      final n = normName(v);
      if (n.isNotEmpty) chans.add({'chan': chId, 'name_norm': n});
    } else if (inProg && tag == 'title' && pTitle == null) {
      pTitle = v;
    } else if (inProg && tag == 'desc' && pDesc == null) {
      pDesc = v;
    }
  }

  for (final e in parseEvents(text)) {
    if (e is XmlStartElementEvent) {
      onStart(e);
      if (e.isSelfClosing) onEnd(e.name);
    } else if (e is XmlEndElementEvent) {
      onEnd(e.name);
    } else if (e is XmlTextEvent) {
      onText(e.value);
    } else if (e is XmlCDATAEvent) {
      onText(e.value);
    }
  }
  return EpgParseResult(chans, progs);
}
