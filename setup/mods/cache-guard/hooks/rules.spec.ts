import { expect, test } from 'bun:test'

import { changedWhat, currentSent, gradient, hex, label, parseThreshold, shouldWarn, warnKey } from './rules.ts'

const last = { model: 'claude-opus-5-5', effort: 'medium' }

test('parseThreshold defaults to 40 and honors a configured value', () => {
  expect(parseThreshold(undefined)).toBe(40)
  expect(parseThreshold(null)).toBe(40)
  expect(parseThreshold(25)).toBe(25)
  expect(parseThreshold('60')).toBe(60)
})

test('currentSent prefers per-model effort, then top-level, then the last sent', () => {
  const settings = { effortLevel: 'low', modelSettings: { 'claude-opus-5-5': { effortLevel: 'high' } } }
  expect(currentSent('claude-opus-5-5', settings, last)).toEqual({ model: 'claude-opus-5-5', effort: 'high' })
  expect(currentSent('other', settings, last)).toEqual({ model: 'other', effort: 'low' })
  expect(currentSent('other', {}, last)).toEqual({ model: 'other', effort: 'medium' })
  expect(currentSent('other', { effortLevel: 3 }, last)).toEqual({ model: 'other', effort: 'medium' })
})

test('label, warnKey and changedWhat describe the change', () => {
  const now = { model: 'claude-opus-5-5', effort: 'high' }
  expect(label(last)).toBe('claude-opus-5-5/medium')
  expect(label({ model: 'm', effort: null })).toBe('m')
  expect(warnKey(last, now)).toBe('claude-opus-5-5/medium->claude-opus-5-5/high')
  expect(changedWhat(last, now)).toBe('effort')
  expect(changedWhat(last, { model: 'm2', effort: 'medium' })).toBe('model')
  expect(changedWhat(last, { model: 'm2', effort: 'high' })).toBe('effort/model')
})

test('shouldWarn needs a change, enough context, and no skip', () => {
  const now = { model: 'claude-opus-5-5', effort: 'high' }
  expect(shouldWarn(last, now, 50, 40, null)).toBe(true)
  expect(shouldWarn(last, now, 40, 40, null)).toBe(true) // at the threshold warns
  expect(shouldWarn(last, now, 39.9, 40, null)).toBe(false) // under it stays quiet
  expect(shouldWarn(last, last, 90, 40, null)).toBe(false) // nothing changed
  expect(shouldWarn(last, now, 90, 40, warnKey(last, now))).toBe(false) // skipped
  expect(shouldWarn(last, now, 90, 40, 'some->other')).toBe(true) // skip was for another change
})

test('gradient keeps every char and runs from one color to the other', () => {
  expect(hex('#fbbf24')).toEqual([251, 191, 36])
  expect(gradient('ab', '#000000', '#ffffff')).toEqual([['a', '#000000'], ['b', '#ffffff']])
  expect(gradient('x', '#102030', '#ffffff')).toEqual([['x', '#102030']])
  expect(gradient('⚠ Warning:', '#fbbf24', '#f472b6').map(([c]) => c).join('')).toBe('⚠ Warning:')
})
