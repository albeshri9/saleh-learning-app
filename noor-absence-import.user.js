// ==UserScript==
// @name         استيراد الغياب إلى نور — أداة المدرسة
// @namespace    local.school.noor.absence
// @version      0.2.0
// @description  معاينة ملف غياب المدرسة ثم تحديد الطلاب ونوع المخالفة في صفحة نور، مع حفظ يدوي.
// @match        https://noor.moe.gov.sa/*
// @run-at       document-idle
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  const MAX_BYTES = 2 * 1024 * 1024;
  const MAX_RECORDS = 1500;
  const EXCUSED = 'excused';
  const UNEXCUSED = 'unexcused';
  const UI_HOST_ID = 'school-noor-absence-import';
  const headers = {
    date: ['date', 'التاريخ', 'تاريخ', 'تاريخ الغياب'],
    school: ['school', 'المدرسة', 'اسم المدرسة'],
    studentName: ['studentName', 'student_name', 'اسم الطالب', 'الطالب'],
    classId: ['classId', 'class_id', 'الفصل', 'الصف والفصل', 'الصف/الفصل'],
    absenceType: ['absenceType', 'absence_type', 'نوع الغياب', 'نوع المخالفة'],
    mode: ['mode', 'النمط', 'نمط الدراسة']
  };
  let imported = null;
  let decisions = new Map();
  let host = null;
  let shadow = null;
  let panel = null;
  let status = null;
  let summary = null;
  let rowsBox = null;
  let applyButton = null;
  let panelOpen = false;
  let checkTimer = 0;

  function westernDigits(value) {
    return String(value ?? '').replace(/[٠-٩۰-۹]/gu, (digit) => {
      const code = digit.charCodeAt(0);
      return String(code >= 0x06F0 ? code - 0x06F0 : code - 0x0660);
    });
  }

  function normalize(value) {
    return westernDigits(value)
      .normalize('NFKC')
      .replace(/[\u064B-\u065F\u0670\u0640]/gu, '')
      .replace(/[أإآٱ]/gu, 'ا')
      .replace(/ى/gu, 'ي')
      .replace(/[\u200C-\u200F\u202A-\u202E]/gu, '')
      .replace(/[\s\u00A0]+/gu, ' ')
      .trim();
  }

  function key(value) {
    return normalize(value).toLowerCase().replace(/[\s_\-/]+/gu, '');
  }

  function parseClass(value) {
    const match = westernDigits(value).trim().match(/^(\d{1,2})\s*[/\-]\s*(\d{1,3})$/u);
    if (!match) return null;
    const grade = Number(match[1]);
    const section = Number(match[2]);
    return grade > 0 && section > 0 ? { grade, section } : null;
  }

  function parseIsoDate(value) {
    const match = westernDigits(value).trim().match(/^(\d{4})-(\d{2})-(\d{2})$/u);
    if (!match) return null;
    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    const date = new Date(Date.UTC(year, month - 1, day));
    return date.getUTCFullYear() === year && date.getUTCMonth() + 1 === month && date.getUTCDate() === day
      ? `${match[1]}-${match[2]}-${match[3]}` : null;
  }

  function parseDelimited(text) {
    const source = String(text).replace(/^\uFEFF/u, '');
    const first = source.split(/\r?\n/u, 1)[0] ?? '';
    const delimiters = [',', ';', '\t'];
    const delimiter = delimiters.sort((a, b) => first.split(b).length - first.split(a).length)[0];
    const result = [];
    let row = [];
    let cell = '';
    let quoted = false;
    for (let i = 0; i < source.length; i += 1) {
      const char = source[i];
      if (quoted) {
        if (char === '"' && source[i + 1] === '"') { cell += '"'; i += 1; }
        else if (char === '"') quoted = false;
        else cell += char;
      } else if (char === '"' && !cell) quoted = true;
      else if (char === delimiter) { row.push(cell); cell = ''; }
      else if (char === '\n' || char === '\r') {
        if (char === '\r' && source[i + 1] === '\n') i += 1;
        row.push(cell); cell = '';
        if (row.some((value) => value.trim())) result.push(row);
        row = [];
      } else cell += char;
    }
    if (quoted) throw new Error('علامات الاقتباس في ملف CSV غير مكتملة.');
    row.push(cell);
    if (row.some((value) => value.trim())) result.push(row);
    return result;
  }

  function parseSpreadsheetXml(text) {
    const xml = new DOMParser().parseFromString(text, 'application/xml');
    if (xml.querySelector('parsererror') || xml.documentElement.localName !== 'Workbook') {
      throw new Error('ملف XLS غير صالح. يدعم السكربت ملف Excel XML فقط؛ استخدم CSV عند حفظ XLSX.');
    }
    const sheet = [...xml.getElementsByTagName('*')].find((node) => node.localName === 'Worksheet');
    if (!sheet) throw new Error('ملف Excel لا يحتوي ورقة عمل.');
    const table = [...sheet.children].find((node) => node.localName === 'Table');
    if (!table) throw new Error('ورقة Excel فارغة.');
    return [...table.children].filter((node) => node.localName === 'Row').map((row) => {
      const values = [];
      for (const cell of [...row.children].filter((node) => node.localName === 'Cell')) {
        const index = Number(cell.getAttributeNS('urn:schemas-microsoft-com:office:spreadsheet', 'Index') || cell.getAttribute('ss:Index'));
        if (Number.isInteger(index) && index > values.length && index < 1000) values.length = index - 1;
        values.push([...cell.children].find((node) => node.localName === 'Data')?.textContent ?? '');
      }
      return values.map((value) => value ?? '');
    }).filter((row) => row.some((value) => String(value).trim()));
  }

  function mapColumns(firstRow) {
    const found = {};
    for (const [field, aliases] of Object.entries(headers)) {
      const indices = firstRow.map((value, index) => aliases.some((alias) => key(value) === key(alias)) ? index : -1).filter((index) => index >= 0);
      if (indices.length > 1) throw new Error(`عنوان العمود ${field} مكرر.`);
      if (indices.length) found[field] = indices[0];
    }
    for (const required of ['date', 'school', 'studentName', 'classId', 'mode']) {
      if (found[required] === undefined) throw new Error(`الملف يفتقد عمود ${required}.`);
    }
    return found;
  }

  function parseImport(text, extension) {
    const table = extension === 'xls' || extension === 'xml' ? parseSpreadsheetXml(text) : parseDelimited(text);
    if (table.length < 2) throw new Error('الملف لا يحتوي قائمة غياب.');
    const columns = mapColumns(table[0]);
    if (table.length - 1 > MAX_RECORDS) throw new Error(`الحد الأقصى ${MAX_RECORDS} طالبًا في الملف.`);
    const records = table.slice(1).map((row, index) => {
      const get = (field) => String(row[columns[field]] ?? '').trim();
      const date = parseIsoDate(get('date'));
      const school = get('school');
      const studentName = get('studentName');
      const classId = get('classId');
      const studentClass = parseClass(classId);
      if (!date || !school || !studentName || !studentClass) {
        throw new Error(`الصف ${index + 2}: يلزم تاريخ YYYY-MM-DD واسم المدرسة والطالب وفصل مثل 1/2.`);
      }
      return {
        sourceRow: index + 2, date, school, studentName, classId, studentClass,
        sourceType: columns.absenceType === undefined ? '' : get('absenceType'),
        mode: get('mode').toUpperCase()
      };
    });
    const dates = new Set(records.map((row) => row.date));
    const schools = new Set(records.map((row) => normalize(row.school)));
    if (dates.size !== 1 || schools.size !== 1) throw new Error('يجب أن يخص الملف تاريخًا واحدًا ومدرسة واحدة.');
    const modes = new Set(records.map((row) => row.mode));
    if (modes.size !== 1 || !['IN_PERSON', 'REMOTE'].includes(records[0].mode)) {
      throw new Error('يجب أن يخص الملف نمط دراسة واحدًا: حضوري أو عن بُعد.');
    }
    const duplicateKeys = new Set();
    const seen = new Set();
    for (const record of records) {
      const identity = `${normalize(record.studentName)}|${record.studentClass.grade}/${record.studentClass.section}`;
      if (seen.has(identity)) duplicateKeys.add(identity);
      seen.add(identity);
      record.identity = identity;
    }
    return { date: records[0].date, school: records[0].school, mode: records[0].mode, records, duplicateKeys };
  }

  function visible(element) {
    if (!element || element.closest('[hidden], [aria-hidden="true"], #school-noor-absence-import')) return false;
    const style = getComputedStyle(element);
    return style.display !== 'none' && style.visibility !== 'hidden' && Boolean(element.getClientRects().length);
  }

  function controlLabel(control) {
    const label = control.labels ? [...control.labels].map((item) => item.textContent).join(' ') : '';
    const nearest = control.closest('td, .form-group, .input-group, label');
    const previousCell = nearest?.tagName === 'TD' ? nearest.previousElementSibling : null;
    return normalize([
      label, control.getAttribute('aria-label'), control.getAttribute('placeholder'),
      control.getAttribute('title'), control.id, control.name,
      nearest?.querySelector('label')?.textContent,
      previousCell && !previousCell.querySelector('input, select, textarea') ? previousCell.textContent : ''
    ].filter(Boolean).join(' '));
  }

  function controlText(control) {
    return control.tagName === 'SELECT' ? String(control.selectedOptions?.[0]?.textContent ?? '') : String(control.value ?? '');
  }

  function splitPageDate(value) {
    const match = westernDigits(value).trim().match(/^(\d{1,4})\s*[-\/.]\s*(\d{1,2})\s*[-\/.]\s*(\d{1,4})$/u);
    if (!match) return null;
    const first = Number(match[1]);
    const second = Number(match[2]);
    const third = Number(match[3]);
    if (first > 1300) return { year: first, month: second, day: third };
    if (third > 1300) return { year: third, month: second, day: first };
    return null;
  }

  function hijriOf(iso) {
    const formatter = new Intl.DateTimeFormat('en-u-ca-islamic-umalqura', { year: 'numeric', month: 'numeric', day: 'numeric', timeZone: 'UTC' });
    const parts = formatter.formatToParts(new Date(`${iso}T12:00:00Z`));
    const value = (type) => Number(parts.find((part) => part.type === type)?.value);
    return { year: value('year'), month: value('month'), day: value('day') };
  }

  function sameDate(pageDate, iso) {
    const expected = pageDate.year < 1700 ? hijriOf(iso) : splitPageDate(iso);
    return Boolean(expected && pageDate.year === expected.year && pageDate.month === expected.month && pageDate.day === expected.day);
  }

  function pageDateEvidence(iso) {
    const controls = [...document.querySelectorAll('input, select')].filter(visible);
    const candidates = controls.filter((control) => control.type === 'date' || /تاريخ|date/iu.test(controlLabel(control)))
      .map((control) => ({ text: controlText(control), parsed: splitPageDate(controlText(control)) }));
    if (!candidates.length) return { ok: false, reason: 'تعذر قراءة تاريخ الغياب من صفحة نور.' };
    if (candidates.some((item) => !item.parsed)) return { ok: false, reason: 'أحد حقول التاريخ في نور فارغ أو غير واضح؛ تأكد من تاريخي «من» و«إلى».' };
    const mismatched = candidates.filter((item) => !sameDate(item.parsed, iso));
    if (mismatched.length) return { ok: false, reason: `تاريخ نور ${mismatched.map((item) => item.text).join('، ')} لا يطابق تاريخ الملف ${iso}.` };
    return { ok: true, text: candidates.map((item) => item.text).join(' / ') };
  }

  function containsSchoolPhrase(value, expected) {
    const text = normalize(String(value).replace(/\r?\n/gu, ' | '));
    const phrase = normalize(expected);
    if (!phrase) return false;
    let at = text.indexOf(phrase);
    while (at !== -1) {
      const before = text.slice(0, at).trimEnd();
      const after = text.slice(at + phrase.length).trimStart();
      if ((!before || /[-–—|•:،؛]$/u.test(before)) && (!after || /^[-–—|•:،؛]/u.test(after))) return true;
      at = text.indexOf(phrase, at + 1);
    }
    return false;
  }

  function pageSchoolEvidence(expected) {
    const controls = [...document.querySelectorAll('input, select')].filter(visible)
      .filter((control) => /المدرسة|school/iu.test(controlLabel(control)))
      .map(controlText).filter((value) => normalize(value));
    if (controls.length) {
      return controls.every((value) => containsSchoolPhrase(value, expected))
        ? { ok: true, text: controls[0] }
        : { ok: false, reason: `اسم المدرسة في نور لا يطابق «${expected}».` };
    }
    const trustedHeaders = [...document.querySelectorAll('header, [role="banner"], h1, h2, h3, h4, #header, .header, .navbar')].filter(visible);
    const candidates = trustedHeaders.flatMap((element) => [element, ...element.querySelectorAll('span, strong, p, div')])
      .filter(visible)
      .map((element) => normalize(element.innerText))
      .filter((text) => text && text.length <= 300);
    const match = candidates.find((text) => containsSchoolPhrase(text, expected));
    return match ? { ok: true, text: match } : { ok: false, reason: `لم يظهر اسم المدرسة «${expected}» صراحةً في ترويسة نور أو خانة المدرسة.` };
  }

  function selectedField(pattern) {
    const candidates = [...document.querySelectorAll('select, input')].filter(visible)
      .filter((control) => pattern.test(controlLabel(control)))
      .map(controlText).map(normalize).filter(Boolean);
    return candidates.length === 1 ? candidates[0] : '';
  }

  function gradeNumber(value) {
    const text = normalize(value);
    const direct = text.match(/(?:^|\s)(\d{1,2})(?:\s|$|\/)/u);
    if (direct) return Number(direct[1]);
    const map = [['الاول', 1], ['الثاني', 2], ['الثالث', 3], ['الرابع', 4], ['الخامس', 5], ['السادس', 6]];
    return map.find(([word]) => text.includes(word))?.[1] ?? null;
  }

  function sectionNumber(value) {
    const text = normalize(value);
    const pair = parseClass(text);
    if (pair) return pair.section;
    const match = text.match(/^(?:الفصل|الشعبة|فصل|شعبة)?\s*(\d{1,3})$/u);
    return match ? Number(match[1]) : null;
  }

  function pageClassScope() {
    const gradeText = selectedField(/الصف|grade/iu);
    const sectionText = selectedField(/الفصل|الشعبة|section/iu);
    const grade = gradeNumber(gradeText);
    const section = sectionNumber(sectionText);
    return grade && section ? { grade, section } : null;
  }

  function workflowEvidence() {
    const controls = [...document.querySelectorAll('select, input')].filter(visible)
      .filter((control) => !['checkbox', 'radio', 'file', 'hidden'].includes(control.type));
    for (const [label, pattern, expected] of [
      ['نوع الحسم', /نوع\s*الحسم/u, 'المواظبة'],
      ['نوع الغياب', /نوع\s*الغياب/u, 'غياب يوم كامل']
    ]) {
      const candidates = controls.filter((control) => pattern.test(controlLabel(control)));
      if (!candidates.length) return { ok: false, reason: `تعذر قراءة حقل «${label}» في نور؛ لا يمكن التحديد قبل ظهوره.` };
      if (candidates.length !== 1 || normalize(controlText(candidates[0])) !== expected) {
        return { ok: false, reason: `اختر «${expected}» في حقل «${label}» في نور قبل التحديد.` };
      }
    }
    return { ok: true };
  }

  function optionFor(select, type) {
    const matches = [...select.options].filter((option) => {
      if (option.disabled || !option.value) return false;
      const text = normalize(option.textContent);
      const unexcused = /(?:بغير|بدون)\s*عذر|غير\s*مبرر/iu.test(text);
      return type === UNEXCUSED ? unexcused : /بعذر/iu.test(text) && !unexcused;
    });
    return matches.length === 1 ? matches[0] : null;
  }

  function headerIndices(table) {
    const heading = [...table.querySelectorAll('tr')].find((row) => row.querySelector('th'));
    if (!heading) return {};
    const cells = [...heading.children].map((cell) => normalize(cell.textContent));
    const find = (pattern) => cells.findIndex((cell) => pattern.test(cell));
    return {
      name: find(/اسم\s*الطالب|^الطالب$/u),
      grade: find(/الصف/u),
      section: find(/الفصل|الشعبة/u)
    };
  }

  function rosterRows() {
    const result = [];
    for (const table of [...document.querySelectorAll('table')].filter(visible)) {
      const columns = headerIndices(table);
      for (const tr of table.querySelectorAll('tr')) {
        if (tr.closest('table') !== table || !visible(tr)) continue;
        const checkboxes = [...tr.querySelectorAll('input[type="checkbox"]')].filter(visible);
        const selects = [...tr.querySelectorAll('select')].filter(visible);
        if (checkboxes.length !== 1 || selects.length !== 1) continue;
        const excusedOption = optionFor(selects[0], EXCUSED);
        const unexcusedOption = optionFor(selects[0], UNEXCUSED);
        if (!excusedOption || !unexcusedOption) continue;
        const cells = [...tr.children].filter((cell) => /^(TD|TH)$/u.test(cell.tagName));
        const texts = cells.map((cell) => normalize(cell.textContent));
        const names = columns.name >= 0 ? [texts[columns.name]] : texts.filter((text) => /[\u0621-\u064A].*\s.*[\u0621-\u064A]/u.test(text) && text.length < 100);
        result.push({
          tr, checkbox: checkboxes[0], select: selects[0], excusedOption, unexcusedOption,
          names: names.filter(Boolean),
          grade: columns.grade >= 0 ? gradeNumber(texts[columns.grade]) : null,
          section: columns.section >= 0 ? sectionNumber(texts[columns.section]) : null
        });
      }
    }
    return result;
  }

  function classMatches(recordClass, row, scope) {
    const grade = row.grade ?? scope?.grade;
    const section = row.section ?? scope?.section;
    return grade === recordClass.grade && section === recordClass.section;
  }

  function preview(data) {
    const date = pageDateEvidence(data.date);
    const school = pageSchoolEvidence(data.school);
    if (data.mode === 'REMOTE') {
      return {
        fatal: [],
        entries: data.records.map((record) => ({ record, status: data.duplicateKeys.has(record.identity) ? 'duplicate' : 'remoteManual' })),
        modeWarnings: [date, school].filter((item) => !item.ok).map((item) => item.reason),
        scope: null, date: date.text, school: school.text
      };
    }
    const workflow = workflowEvidence();
    if (!workflow.ok || !date.ok || !school.ok) return { fatal: [workflow, date, school].filter((item) => !item.ok).map((item) => item.reason), entries: [] };
    const rows = rosterRows();
    if (!rows.length) return { fatal: ['لم يظهر جدول طلاب نور أو قوائم نوع المخالفة بعد الضغط على «بحث».'], entries: [] };
    const rosterTables = [...new Set(rows.map((row) => row.tr.closest('table')))];
    const preselected = rosterTables.flatMap((table) => [...table.querySelectorAll('input[type="checkbox"]')])
      .filter((checkbox) => visible(checkbox) && checkbox.checked);
    if (preselected.length) return { fatal: [`يوجد ${preselected.length} مربع تحديد مختار مسبقًا في جدول نور، وقد يشمل طلابًا خارج الملف. راجع التحديدات وألغِها يدويًا ثم حدّث المعاينة.`], entries: [] };
    const scope = pageClassScope();
    const entries = data.records.map((record) => {
      if (data.duplicateKeys.has(record.identity)) return { record, status: 'duplicate' };
      if (scope && (scope.grade !== record.studentClass.grade || scope.section !== record.studentClass.section)) return { record, status: 'outside' };
      const nameMatches = rows.filter((row) => row.names.some((name) => normalize(name) === normalize(record.studentName)));
      const matches = nameMatches.filter((row) => classMatches(record.studentClass, row, scope));
      if (matches.length > 1) return { record, status: 'ambiguous' };
      if (!matches.length) return { record, status: nameMatches.length ? 'classMismatch' : 'notFound' };
      if (matches[0].checkbox.checked) return { record, status: 'alreadySelected', row: matches[0] };
      return { record, status: 'ready', row: matches[0] };
    });
    const targets = new Map();
    for (const entry of entries.filter((item) => item.status === 'ready')) {
      const previous = targets.get(entry.row.tr);
      if (previous) { previous.status = 'ambiguous'; entry.status = 'ambiguous'; }
      else targets.set(entry.row.tr, entry);
    }
    return { fatal: [], entries, scope, date: date.text, school: school.text };
  }

  function el(tag, className = '', text = '') {
    const element = document.createElement(tag);
    element.className = className;
    element.textContent = text;
    return element;
  }

  function setStatus(message, error = false) {
    status.textContent = message;
    status.className = error ? 'notice error' : 'notice';
  }

  function statusLabel(value) {
    return {
      ready: 'جاهز', outside: 'فصل آخر', duplicate: 'مكرر في الملف', ambiguous: 'مطابقة ملتبسة',
      classMismatch: 'الاسم موجود والفصل مختلف', notFound: 'غير موجود في الجدول',
      alreadySelected: 'محدد مسبقًا في نور', remoteManual: 'عن بُعد — إدخال يدوي في نور'
    }[value] ?? value;
  }

  function render() {
    if (!imported) return;
    const result = preview(imported);
    rowsBox.replaceChildren();
    if (result.fatal.length) {
      summary.textContent = `${imported.records.length} طالبًا في الملف · ${imported.school} · ${imported.date}`;
      setStatus(result.fatal.join(' '), true);
      applyButton.disabled = true;
      return;
    }
    const count = (statusName) => result.entries.filter((entry) => entry.status === statusName).length;
    const ready = count('ready');
    const outside = count('outside');
    const problems = result.entries.filter((entry) => !['ready', 'outside'].includes(entry.status));
    const unexcused = result.entries.filter((entry) => entry.status === 'ready' && decisions.get(entry.record.sourceRow) === UNEXCUSED).length;
    summary.textContent = imported.mode === 'REMOTE'
      ? `ملف غياب عن بُعد · ${imported.records.length} طالبًا · ${imported.school} · ${imported.date}`
      : `جاهز: ${ready} · بعذر: ${ready - unexcused} · بغير عذر: ${unexcused} · فصول أخرى: ${outside} · تحتاج مراجعة: ${problems.length}`;
    const ignoredTypes = imported.records.filter((record) => record.sourceType && !/^(?:الغياب\s*)?بعذر$/u.test(normalize(record.sourceType))).length;
    const sourceNotice = ignoredTypes ? ` ${ignoredTypes} حالة في الملف لها نوع آخر؛ بدأت بعذر ويمكن تغييرها يدويًا هنا.` : '';
    const modeNotice = imported.mode === 'REMOTE'
      ? ' هذا الملف للدراسة عن بُعد. راجع الأسماء، ثم اختر نوع الغياب الصحيح وأدخل الحالات يدويًا في نور؛ لا يحدد السكربت هؤلاء الطلاب آليًا حتى نتأكد من نوع المخالفة المناسب في نور.'
      : '';
    const modeWarnings = result.modeWarnings?.length ? ` ${result.modeWarnings.join(' ')}` : '';
    setStatus((problems.length && imported.mode !== 'REMOTE' ? 'راجع الحالات غير المطابقة قبل التحديد. يمكنك إعادة البحث في نور ثم تحديث المعاينة.' : `الملف مقروء. ${result.scope ? `الفصل ${result.scope.grade}/${result.scope.section}.` : 'راجع الفصل في كل صف.'}`) + modeNotice + modeWarnings + sourceNotice, Boolean(modeNotice || modeWarnings));
    for (const entry of result.entries) {
      if (entry.status === 'outside') continue;
      const item = el('div', `student ${entry.status === 'ready' ? '' : 'problem'}`);
      const identity = el('div', 'student-name', `${entry.record.studentName} · ${entry.record.classId}`);
      const label = el('span', 'tag', statusLabel(entry.status));
      item.append(identity, label);
      if (entry.status === 'ready') {
        const select = el('select', 'type-select');
        select.setAttribute('aria-label', `نوع غياب ${entry.record.studentName}`);
        const excused = el('option', '', 'غياب بعذر'); excused.value = EXCUSED;
        const unexcusedOption = el('option', '', 'غياب بغير عذر'); unexcusedOption.value = UNEXCUSED;
        select.append(excused, unexcusedOption);
        select.value = decisions.get(entry.record.sourceRow) ?? EXCUSED;
        select.addEventListener('change', () => { decisions.set(entry.record.sourceRow, select.value); render(); });
        item.append(select);
      }
      rowsBox.append(item);
    }
    applyButton.disabled = ready === 0 || problems.length > 0;
  }

  async function readFile(file) {
    if (!file) return;
    if (file.size > MAX_BYTES) throw new Error('حجم الملف يتجاوز 2 ميغابايت.');
    const extension = file.name.split('.').pop()?.toLowerCase();
    if (!['csv', 'xls', 'xml'].includes(extension)) throw new Error('اختر ملف CSV أو Excel XML بصيغة XLS. لا يدعم هذا الإصدار XLSX.');
    const text = await file.text();
    if (text.includes('\uFFFD')) throw new Error('تعذر قراءة ترميز الملف. احفظه بصيغة CSV UTF-8.');
    imported = parseImport(text, extension);
    decisions = new Map();
    render();
  }

  function applyImport() {
    if (!imported) return;
    const result = preview(imported);
    const ready = result.entries.filter((entry) => entry.status === 'ready');
    const problems = result.entries.filter((entry) => !['ready', 'outside'].includes(entry.status));
    if (result.fatal.length || problems.length || !ready.length) { render(); return; }
    // Recheck every target before the first modification. Noor may have refreshed its table.
    if (ready.some((entry) => !entry.row.tr.isConnected || entry.row.checkbox.checked || entry.row.checkbox.disabled ||
      !optionFor(entry.row.select, decisions.get(entry.record.sourceRow) ?? EXCUSED))) {
      setStatus('تغير جدول نور. اضغط تحديث المعاينة ثم حاول مجددًا.', true);
      return;
    }
    let applied = 0;
    for (const entry of ready) {
      const target = entry.row;
      if (!target.tr.isConnected) break;
      const desired = decisions.get(entry.record.sourceRow) ?? EXCUSED;
      const option = optionFor(target.select, desired);
      if (!option) break;
      target.checkbox.click();
      if (!target.checkbox.checked || target.select.disabled) break;
      target.select.value = option.value;
      target.select.dispatchEvent(new Event('input', { bubbles: true }));
      target.select.dispatchEvent(new Event('change', { bubbles: true }));
      if (!target.tr.isConnected || target.select.value !== option.value) break;
      applied += 1;
    }
    setStatus(applied === ready.length
      ? `حُدد ${applied} طالبًا في نور. راجع الأنواع والطلاب ثم اضغط «حفظ» في نور بنفسك.`
      : `حُدد ${applied} من ${ready.length} فقط؛ تغيرت الصفحة أثناء التنفيذ. راجع جدول نور قبل الحفظ.`, applied !== ready.length);
    applyButton.disabled = true;
  }

  function isAttendancePage() {
    const text = normalize(document.body?.textContent ?? '');
    return /ادخال السلوك والمواظبة/u.test(text) || (/المواظبة/u.test(text) && /غياب يوم كامل/u.test(text)) || rosterRows().length > 0;
  }

  function buildUi() {
    host = document.createElement('div'); host.id = UI_HOST_ID;
    shadow = host.attachShadow({ mode: 'open' });
    const style = document.createElement('style');
    style.textContent = `
      :host { all: initial; direction: rtl; font: 15px/1.6 system-ui, sans-serif; color: #153248; }
      * { box-sizing: border-box; }
      button, select, input { font: inherit; }
      .launch { position: fixed; z-index: 2147483647; left: 16px; bottom: 16px; border: 0; border-radius: 999px; padding: 12px 18px; background: #087e94; color: white; box-shadow: 0 4px 18px #0004; font-weight: 700; cursor: pointer; }
      .panel { position: fixed; z-index: 2147483647; left: 12px; bottom: 70px; width: min(430px, calc(100vw - 24px)); max-height: min(85vh, 760px); display: flex; flex-direction: column; overflow: hidden; border: 1px solid #c6dce0; border-radius: 16px; background: #fff; box-shadow: 0 14px 42px #0005; }
      .hidden { display: none !important; }
      .head { display: flex; justify-content: space-between; align-items: center; gap: 12px; padding: 14px 16px; background: #e9f5f7; }
      .head strong { font-size: 17px; }
      .close { border: 0; background: transparent; color: #153248; font-size: 24px; cursor: pointer; }
      .body { padding: 15px; overflow: auto; }
      p { margin: 0 0 12px; }
      .file { display: block; width: 100%; margin: 10px 0 14px; }
      .notice { padding: 10px 12px; border-radius: 9px; background: #eef7fb; margin: 10px 0; }
      .warning { padding: 10px 12px; border: 1px solid #c77b2a; border-radius: 9px; background: #fff4df; color: #66400b; font-weight: 700; }
      .error, .problem { background: #fff1e8 !important; color: #713a1a; }
      .summary { font-weight: 700; margin: 8px 0; }
      .student-list { max-height: 280px; overflow: auto; border: 1px solid #d5e2e5; border-radius: 10px; }
      .student { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; padding: 9px; border-bottom: 1px solid #e4ecee; }
      .student:last-child { border-bottom: 0; }
      .student-name { flex: 1 1 150px; font-weight: 600; }
      .tag { color: #4f6470; font-size: 12px; }
      .type-select { width: 100%; padding: 7px; border: 1px solid #a9c4ca; border-radius: 7px; background: white; }
      .actions { display: flex; gap: 8px; margin-top: 12px; }
      .actions button { flex: 1; padding: 9px; border: 1px solid #087e94; border-radius: 8px; background: #fff; color: #076779; cursor: pointer; }
      .actions button.primary { background: #087e94; color: white; }
      .actions button:disabled { opacity: .5; cursor: not-allowed; }
      .small { font-size: 12px; color: #51616a; }
      @media (max-width: 600px) { .panel { left: 0; bottom: 0; width: 100vw; max-height: 90dvh; border-radius: 16px 16px 0 0; } .launch { bottom: 12px; left: 12px; } }
    `;
    const launch = el('button', 'launch', 'استيراد الغياب'); launch.type = 'button';
    panel = el('section', 'panel hidden'); panel.setAttribute('dir', 'rtl'); panel.setAttribute('aria-label', 'استيراد الغياب إلى نور');
    const head = el('div', 'head');
    const title = el('strong', '', 'استيراد غياب اليوم');
    const close = el('button', 'close', '×'); close.type = 'button'; close.setAttribute('aria-label', 'إغلاق');
    head.append(title, close);
    const body = el('div', 'body');
    const intro = el('p', '', 'افتح شاشة غياب يوم كامل في نور، اختر التاريخ والفصل واضغط «بحث»، ثم اختر ملف الغياب.');
    const warning = el('p', 'warning', 'قائمة الغياب مشتقة من قاعدة رصد المدرسة؛ راجع استحقاق غياب يوم كامل ونوع العذر لكل طالب قبل حفظ نور.');
    const file = el('input', 'file'); file.type = 'file'; file.accept = '.csv,.xls,.xml,text/csv,application/vnd.ms-excel'; file.setAttribute('aria-label', 'ملف الغياب');
    summary = el('div', 'summary', 'لم يُختر ملف بعد.');
    status = el('div', 'notice', 'الغياب بعذر هو الخيار الأول لكل طالب. يمكن تغيير كل حالة هنا قبل التحديد.');
    rowsBox = el('div', 'student-list');
    const actions = el('div', 'actions');
    const refresh = el('button', '', 'تحديث المعاينة'); refresh.type = 'button';
    applyButton = el('button', 'primary', 'تحديد في نور'); applyButton.type = 'button'; applyButton.disabled = true;
    actions.append(refresh, applyButton);
    const foot = el('p', 'small', 'بعد التحديد راجع الجدول بنفسك. الأداة لا تضع إقرار صحة البيانات ولا تضغط «حفظ».');
    body.append(intro, warning, file, summary, status, rowsBox, actions, foot);
    panel.append(head, body);
    shadow.append(style, launch, panel);
    document.body.append(host);
    const toggle = (open) => { panelOpen = open; panel.classList.toggle('hidden', !open); launch.classList.toggle('hidden', open); if (open && imported) render(); };
    launch.addEventListener('click', () => toggle(true));
    close.addEventListener('click', () => toggle(false));
    refresh.addEventListener('click', render);
    applyButton.addEventListener('click', applyImport);
    file.addEventListener('change', async () => {
      try { await readFile(file.files?.[0]); }
      catch (error) { imported = null; decisions = new Map(); rowsBox.replaceChildren(); summary.textContent = 'لم يُقبل الملف.'; applyButton.disabled = true; setStatus(error.message, true); }
      file.value = '';
    });
  }

  function syncUi() {
    checkTimer = 0;
    if (!document.body) return;
    const active = isAttendancePage();
    if (active && !host) buildUi();
    else if (!active && host) { host.remove(); host = null; shadow = null; panel = null; panelOpen = false; }
  }

  if (globalThis.__NOOR_ABSENCE_TEST_MODE__ === true) {
    globalThis.__NOOR_ABSENCE_TEST_API__ = { normalize, parseClass, parseIsoDate, parseDelimited, parseImport, preview, sameDate, gradeNumber, sectionNumber, classMatches, optionFor, containsSchoolPhrase, pageDateEvidence, pageSchoolEvidence, workflowEvidence };
    return;
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', syncUi, { once: true });
  else syncUi();
  const observer = new MutationObserver(() => {
    if (!checkTimer) checkTimer = window.setTimeout(syncUi, 300);
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
})();
