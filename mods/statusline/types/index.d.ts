export type Run = {
  text: string
  color?: string
  backgroundColor?: string
  bold?: boolean
  italic?: boolean
}

declare module 'claude-code' {
  interface PluginState {
    statusline: { line: Run[] | null }
  }
}
