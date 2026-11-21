import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Run } from '../types'

// Runs bin/statusline.sh (taipingeric/agent-config) with the same JSON the CLI's
// statusLine command gets, turns its ANSI colors into colored runs, and draws
// them as a full-width row above the prompt.

const line = atom({ plugin: 'statusline', key: 'line' } as const, null)

let effort: string | undefined
let style: string | undefined
let isRunning = false

const toEpoch = (iso?: string) => {
  if (!iso) return undefined
  const ms = Date.parse(iso)
  return Number.isNaN(ms) ? undefined : Math.floor(ms / 1000)
}

// The apps show colors a little differently from the macOS terminal. So each color
// statusline.sh prints is given to the apps as the value that the app shows the
// same as the terminal does, measured off a screenshot of both side by side
// (2026-11-22). Colors not measured yet pass through as they are.
const APP_COLOR: Record<string, string> = {
  'rgb(120,150,255)': 'rgb(112,151,255)', // folder (bold_blue)
  'rgb(0,194,0)': 'rgb(0,198,0)', // branch (green)
  'rgb(199,196,0)': 'rgb(200,196,0)', // dirty * (yellow)
  'rgb(217,119,87)': 'rgb(234,113,80)', // model (orange)
  'rgb(192,64,190)': 'rgb(210,52,197)', // effort (magenta)
  'rgb(95,175,95)': 'rgb(64,178,85)', // ctx under 20% (xterm 71)
  'rgb(167,171,242)': 'rgb(166,171,248)', // 5h (bright_blue)
  'rgb(255,85,85)': 'rgb(255,66,77)', // low quota (bright_red)
}

// xterm's 256-color palette as rgb().
const BASIC = [
  '0,0,0', '205,0,0', '0,205,0', '205,205,0', '0,0,238', '205,0,205', '0,205,205', '229,229,229',
  '127,127,127', '255,0,0', '0,255,0', '255,255,0', '92,92,255', '255,0,255', '0,255,255', '255,255,255',
]
const xterm = (n: number) => {
  if (n < 16) return `rgb(${BASIC[n]})`
  if (n < 232) {
    const lv = [0, 95, 135, 175, 215, 255]
    const i = n - 16
    return `rgb(${lv[Math.floor(i / 36)]},${lv[Math.floor(i / 6) % 6]},${lv[i % 6]})`
  }
  const g = 8 + 10 * (n - 232)
  return `rgb(${g},${g},${g})`
}

// ANSI SGR text -> runs. Reverse video (the filled bar cells) is drawn as a
// background in the current color, so the bars keep their look.
const parse = (s: string): Run[] => {
  const runs: Run[] = []
  let fg: string | undefined
  let bg: string | undefined
  let bold = false
  let italic = false
  let inverse = false
  const push = (text: string) => {
    if (!text) return
    const run: Run = inverse
      ? { text, color: bg ?? 'rgb(30,30,30)', backgroundColor: fg ?? 'rgb(220,220,220)' }
      : { text, color: fg, backgroundColor: bg }
    if (bold) run.bold = true
    if (italic) run.italic = true
    const prev = runs[runs.length - 1]
    if (prev && prev.color === run.color && prev.backgroundColor === run.backgroundColor &&
        prev.bold === run.bold && prev.italic === run.italic) prev.text += text
    else runs.push(run)
  }
  const re = /\x1b\[([0-9;]*)m/g
  let at = 0
  for (let m = re.exec(s); m; m = re.exec(s)) {
    push(s.slice(at, m.index))
    at = re.lastIndex
    const codes = (m[1] || '0').split(';').map(Number)
    for (let i = 0; i < codes.length; i++) {
      const c = codes[i]
      if (c === 0) { fg = bg = undefined; bold = italic = inverse = false }
      else if (c === 1) bold = true
      else if (c === 3) italic = true
      else if (c === 7) inverse = true
      else if (c === 27) inverse = false
      else if (c === 39) fg = undefined
      else if (c === 49) bg = undefined
      else if (c === 38 || c === 48) {
        let color: string | undefined
        if (codes[i + 1] === 5) { color = xterm(codes[i + 2] ?? 0); i += 2 }
        else if (codes[i + 1] === 2) { color = `rgb(${codes[i + 2]},${codes[i + 3]},${codes[i + 4]})`; i += 4 }
        if (c === 38) fg = color
        else bg = color
      }
    }
  }
  push(s.slice(at))
  return runs
}

const refresh = async ($: EngineInterface) => {
  if (isRunning) return
  isRunning = true
  try {
    const [cwd, model, usage] = await Promise.all([
      $.session.cwd(),
      $.session.model(),
      $.session.usage(),
    ])
    const limit = (kind: string) => usage.rateLimits.find(r => r.kind === kind)
    const h5 = limit('five_hour')
    const wk = limit('seven_day')
    const pct = usage.context.percent

    const input = {
      cwd,
      workspace: { current_dir: cwd },
      model: { display_name: model },
      effort: effort ? { level: effort } : undefined,
      context_window: pct === undefined ? undefined : { remaining_percentage: 100 - pct },
      rate_limits: {
        five_hour: h5 && { used_percentage: h5.percentUsed, resets_at: toEpoch(h5.resetsAt) },
        seven_day: wk && { used_percentage: wk.percentUsed, resets_at: toEpoch(wk.resetsAt) },
      },
      output_style: style ? { name: style } : undefined,
    }

    const ran = await $.process.run(['bash', `${$.plugin.root}/bin/statusline.sh`], {
      cwd,
      stdin: JSON.stringify(input),
      env: { STATUSLINE_WIDTH: '1000' },
      timeoutMs: 15_000,
    })
    const text = ran.stdout.replace(/\n+$/, '')
    if (ran.exitCode === 0 && text) await update($, line, () => parse(text))
  } catch {
    // Keep the last line on screen; the next refresh tries again.
  } finally {
    isRunning = false
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const r = await next(e)
    $.ui.status(undefined)
    void refresh($)
    $.clock.every(30_000, () => void refresh($))
    return r
  })

  on('prompt.compose', ($, e, next) => {
    style = e.outputStyle?.name
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    if (typeof e.effort === 'string') effort = e.effort
    const r = yield* next(e)
    void refresh($)
    return r
  })

  on('tool.call', async ($, e, next) => {
    const r = await next(e)
    void refresh($)
    return r
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const runs = await read($, line)
    if (e.props.hasSurvey || !runs || runs.length === 0) return next(e)

    const { Box, Text } = $.ui.resolve(e)
    // The terminal keeps its own background and colors. The apps draw the row on
    // pure black, a little heavier (their small type washes thin colors out), in
    // the terminal's colors (APP_COLOR).
    const isTerminal = e.surface === 'terminal'
    const look = (r: Run): Run => {
      if (isTerminal) return r
      const app = (c?: string) => (c && APP_COLOR[c]) || c
      return { ...r, color: app(r.color), backgroundColor: app(r.backgroundColor) }
    }
    const row = (
      <Text mono size="footnote" weight={isTerminal ? undefined : 'medium'}>
        {runs.map(look).map(r => (
          <Text
            color={r.color}
            backgroundColor={r.backgroundColor}
            bold={r.bold}
            italic={r.italic}
          >
            {r.text}
          </Text>
        ))}
      </Text>
    )
    if (isTerminal) return row
    return (
      <Box backgroundColor="#000000" paddingX={1} flexGrow={1}>
        {row}
      </Box>
    )
  })
}
