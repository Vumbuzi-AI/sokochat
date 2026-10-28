export function thinkingLevel(model: string, configured?: string): 'off' | 'low' {
  const level = configured || (model === 'gpt-5.5' ? 'off' : 'low');
  if (level !== 'off' && level !== 'low') throw new Error('PI_THINKING_LEVEL must be off or low');
  return level;
}
