// Group-two fatha templates, normalized from the same open-letter reference
// proportions used by the earlier lessons.
part of 'letter_trace_template.dart';

const _group2Fatha = LetterTracePart(
  id: 'fatha',
  revealWidthFactor: .16,
  outline: [
    Offset(.67, .05), Offset(.38, .10), Offset(.36, .16),
    Offset(.65, .11),
  ],
  centerline: [Offset(.64, .08), Offset(.39, .13)],
);

const _dalBody = LetterTracePart(
  id: 'body',
  smoothOutline: true,
  revealWidthFactor: .20,
  outline: [
    Offset(.70, .31), Offset(.82, .38), Offset(.89, .50),
    Offset(.88, .62), Offset(.79, .72), Offset(.63, .77),
    Offset(.42, .78), Offset(.22, .76), Offset(.17, .69),
    Offset(.23, .63), Offset(.42, .65), Offset(.60, .63),
    Offset(.70, .58), Offset(.72, .51), Offset(.65, .45),
    Offset(.54, .40), Offset(.57, .32),
  ],
  centerline: [
    Offset(.61, .34), Offset(.72, .39), Offset(.79, .47),
    Offset(.80, .56), Offset(.73, .63), Offset(.60, .68),
    Offset(.42, .70), Offset(.24, .69),
  ],
);

const _raaBody = LetterTracePart(
  id: 'body',
  smoothOutline: true,
  revealWidthFactor: .22,
  outline: [
    Offset(.69, .28), Offset(.82, .34), Offset(.84, .46),
    Offset(.78, .58), Offset(.67, .70), Offset(.53, .82),
    Offset(.36, .91), Offset(.19, .94), Offset(.14, .87),
    Offset(.27, .80), Offset(.39, .70), Offset(.51, .58),
    Offset(.58, .47), Offset(.57, .35),
  ],
  centerline: [
    Offset(.64, .32), Offset(.71, .39), Offset(.71, .48),
    Offset(.64, .59), Offset(.53, .70), Offset(.40, .81),
    Offset(.23, .89),
  ],
);

const _upperDot = LetterTracePart(
  id: 'dot1',
  isDot: true,
  smoothOutline: true,
  revealWidthFactor: .14,
  outline: [
    Offset(.57, .21), Offset(.62, .17), Offset(.69, .18),
    Offset(.73, .23), Offset(.70, .28), Offset(.63, .29),
    Offset(.57, .26),
  ],
  centerline: [Offset(.65, .23)],
);

const dalFathaTemplate = LetterTraceTemplate(
  id: 'dal_fatha_pdf_v1',
  aspectRatio: 1.08,
  widthFactor: .78,
  heightFactor: .84,
  parts: [_dalBody, _group2Fatha],
);

const dhalFathaTemplate = LetterTraceTemplate(
  id: 'dhal_fatha_pdf_v1',
  aspectRatio: 1.08,
  widthFactor: .78,
  heightFactor: .84,
  parts: [_dalBody, _upperDot, _group2Fatha],
);

const raaFathaTemplate = LetterTraceTemplate(
  id: 'raa_fatha_pdf_v1',
  aspectRatio: .78,
  widthFactor: .66,
  heightFactor: .88,
  parts: [_raaBody, _group2Fatha],
);

const zayFathaTemplate = LetterTraceTemplate(
  id: 'zay_fatha_pdf_v1',
  aspectRatio: .78,
  widthFactor: .66,
  heightFactor: .88,
  parts: [_raaBody, _upperDot, _group2Fatha],
);

const seenFathaTemplate = LetterTraceTemplate(
  id: 'seen_fatha_pdf_v1',
  aspectRatio: 1.42,
  widthFactor: .88,
  heightFactor: .82,
  parts: [
    LetterTracePart(
      id: 'body',
      smoothOutline: true,
      revealWidthFactor: .13,
      outline: [
        Offset(.91, .38), Offset(.96, .43), Offset(.96, .53),
        Offset(.91, .60), Offset(.83, .61), Offset(.77, .57),
        Offset(.71, .63), Offset(.62, .63), Offset(.55, .58),
        Offset(.49, .64), Offset(.39, .65), Offset(.30, .62),
        Offset(.24, .56), Offset(.22, .68), Offset(.17, .78),
        Offset(.09, .84), Offset(.03, .79), Offset(.10, .70),
        Offset(.13, .58), Offset(.15, .43), Offset(.22, .42),
        Offset(.27, .51), Offset(.34, .55), Offset(.43, .55),
        Offset(.47, .48), Offset(.52, .47), Offset(.57, .54),
        Offset(.65, .54), Offset(.70, .47), Offset(.75, .46),
        Offset(.80, .53), Offset(.87, .52), Offset(.89, .46),
      ],
      centerline: [
        Offset(.92, .42), Offset(.92, .50), Offset(.87, .56),
        Offset(.81, .55), Offset(.76, .50), Offset(.72, .55),
        Offset(.66, .59), Offset(.59, .57), Offset(.53, .51),
        Offset(.48, .57), Offset(.41, .60), Offset(.33, .58),
        Offset(.26, .52), Offset(.20, .47), Offset(.19, .60),
        Offset(.16, .72), Offset(.10, .80),
      ],
    ),
    _group2Fatha,
  ],
);
