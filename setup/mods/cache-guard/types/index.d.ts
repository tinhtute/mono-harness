export type Sent = { model: string; effort: string | null }

declare module 'claude-code' {
  interface PluginState {
    'cache-guard': { sent: Sent | null; dismissed: string | null; busy: boolean }
  }
}
