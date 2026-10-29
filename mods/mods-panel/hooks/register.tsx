import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

const PANE = 'mods-panel'
const ORANGE = '#D97757'
const HORN = '#F5EFE6'
const changes = atom({ plugin: 'mods-panel', key: 'changes' } as const, 0)

export const register: Register = on => {
  // The OFF list this load started from; a different list now means a reload is due.
  let applied: string | null = null

  // The gate: a mod on the OFF list does not load. Every mod it sees is
  // remembered, so the panel lists mods wherever they were installed from.
  on('plugin.register', async ($, e, next) => {
    const off = ((await $.store.get('off')) ?? []) as string[]
    const seen = ((await $.store.get('seen')) ?? []) as string[]
    const isOther = e.name !== $.plugin.name && !e.provenance.endsWith('@builtin')

    if (isOther && !seen.includes(e.name)) {
      await $.store.set('seen', [...seen, e.name])
    }

    if (isOther && off.includes(e.name)) {
      return { refuse: `${$.plugin.name}: ${e.name} is switched OFF.` }
    }

    return next(e)
  }).catch(($, e, next) => (next.called ? next(e) : { allow: true }))

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'mods-panel',
      description: 'Open the pane that switches mods ON or OFF',
    })
    applied = JSON.stringify([...(((await $.store.get('off')) ?? []) as string[])].sort())

    return next(e)
  })

  on('command.run', { command: 'mods-panel' }, async $ => {
    await $.ui.open({ id: PANE, title: 'Mods Panel' })

    return { text: 'Mods pane opened.' }
  })

  // The switches: one button per mod seen loading, plus each folder under
  // ~/.claude/dev-mods (so a mod switched OFF before it was ever seen still shows).
  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    await read($, changes)

    const found = new Set(((await $.store.get('seen')) ?? []) as string[])
    const home = $.plugin.root.split('/.claude/')[0]
    const devMods = `${home}/.claude/dev-mods`
    try {
      for (const session of await $.fs.list(devMods)) {
        if (session.kind !== 'dir') continue
        for (const mod of await $.fs.list(`${devMods}/${session.name}`)) {
          if (mod.kind === 'dir') found.add(mod.name)
        }
      }
    } catch {
      // No dev-mods folder: the mods seen loading are the list.
    }
    found.delete($.plugin.name)
    const names = [...found].sort()

    const off = ((await $.store.get('off')) ?? []) as string[]
    const { Box, Button, Text } = $.ui.resolve(e)
    const isDirty = applied !== null && JSON.stringify([...off].sort()) !== applied
    const offCount = names.filter(n => off.includes(n)).length

    return (
      <Box flexDirection="column" paddingX={1}>
        <Box>
          <Box flexDirection="column" marginRight={2}>
            <Text color={HORN}>{'\u00a0▟\u00a0\u00a0\u00a0\u00a0\u00a0▙\u00a0'}</Text>
            <Box>
              <Text color={ORANGE}>{'▗'}</Text>
              <Text color="black" backgroundColor={ORANGE}>{'\u00a0▗\u00a0\u00a0\u00a0▖\u00a0'}</Text>
              <Text color={ORANGE}>{'▖'}</Text>
            </Box>
            <Box>
              <Text>{'\u00a0'}</Text>
              <Text backgroundColor={ORANGE}>{'\u00a0\u00a0\u00a0\u00a0\u00a0\u00a0\u00a0'}</Text>
              <Text>{'\u00a0'}</Text>
            </Box>
            <Text color={ORANGE}>{'\u00a0▘▘\u00a0\u00a0\u00a0▝▝\u00a0'}</Text>
          </Box>
          <Box flexDirection="column">
            <Text bold color={ORANGE}>Mods Panel</Text>
            <Text dimColor>
              {names.length - offCount} on · {offCount} off
            </Text>
            {isDirty ? (
              <Text>
                Changed! Now run{' '}
                <Text bold color="black" backgroundColor="#FFD60A">
                  {' /reload-plugins '}
                </Text>
              </Text>
            ) : (
              <Text dimColor>Press a switch to turn a mod ON or OFF.</Text>
            )}
          </Box>
        </Box>
        <Text dimColor>{'─'.repeat(36)}</Text>
        {names.length === 0 && <Text dimColor>No mods found.</Text>}
        {names.map(name => {
          const isOff = off.includes(name)

          return (
            <Box key={`row-${name}`}>
              <Button
                key={`toggle-${name}`}
                label={isOff ? 'OFF' : 'ON'}
                onPress={async () => {
                  const now = ((await $.store.get('off')) ?? []) as string[]
                  const updated = now.includes(name)
                    ? now.filter(n => n !== name)
                    : [...now, name]
                  await $.store.set('off', updated)
                  await update($, changes, n => n + 1)
                  $.ui.toast(`${name}: ${updated.includes(name) ? 'OFF' : 'ON'} (run /reload-plugins to apply)`)
                }}
              />
              <Text dimColor={isOff}> {name}</Text>
            </Box>
          )
        })}
      </Box>
    )
  })
}
