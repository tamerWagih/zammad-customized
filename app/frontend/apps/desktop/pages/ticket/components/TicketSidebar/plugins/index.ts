// Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

import { useSessionStore } from '#shared/stores/session.ts'

import type { TicketSidebarScreenType } from '#desktop/pages/ticket/types/sidebar.ts'

import type { TicketSidebarPlugin } from './types.ts'

const pluginModules = import.meta.glob<TicketSidebarPlugin>(
  ['./**/*.ts', '!./**/index.ts', '!./types.ts', '!./__tests__/**/*.ts'],
  {
    eager: true,
    import: 'default',
  },
)

export const pluginFiles = Object.entries(pluginModules)
  .map<[string, TicketSidebarPlugin]>(([file, plugin]) => {
    const name = file.replace(/^.*\/([^/]+)\.ts$/, '$1')
    return [name, plugin]
  })
  .sort(([, p1], [, p2]) => p1.order - p2.order)

// Debug: print loaded sidebar plugins (temporary)
try {
  // eslint-disable-next-line no-console
  console.log('[Sidebar] Loaded plugins:', Object.keys(Object.fromEntries(pluginFiles)))
} catch {}

export const useTicketSidebarPlugins = (screen: TicketSidebarScreenType) => {
  const { hasPermission } = useSessionStore()

  return pluginFiles
    .filter(
      ([, plugin]) =>
        hasPermission(plugin.permissions) && plugin.screens.includes(screen),
    )
    .reduce<Record<string, TicketSidebarPlugin>>((acc, [name, plugin]) => {
      acc[name] = plugin
      return acc
    }, {})
}
