/** "You're next" texts for remote queue customers (push + in-app inbox). */

export type Language = 'en' | 'am';

/** `type` of the inbox entry users/{uid}/notifications/{id}. */
export const QUEUE_NEXT_TYPE = 'queueNext';

export function normalizeLanguage(value: unknown, fallback: Language = 'en'): Language {
  if (typeof value !== 'string') return fallback;
  const code = value.toLowerCase().split(/[-_]/)[0];
  return code === 'am' ? 'am' : code === 'en' ? 'en' : fallback;
}

export function renderQueueNext(
  language: Language,
  shopName: string | null | undefined,
): { title: string; body: string } {
  const shop = (shopName ?? '').trim();
  if (language === 'am') {
    return {
      title: 'ቀጣዩ እርስዎ ነዎት',
      body: shop
        ? `በ${shop} ወረፋ ቀጣዩ እርስዎ ነዎት። እባክዎ አሁን ወደ ፀጉር ቤቱ ይምጡ።`
        : 'በወረፋው ቀጣዩ እርስዎ ነዎት። እባክዎ አሁን ወደ ፀጉር ቤቱ ይምጡ።',
    };
  }
  return {
    title: "You're next",
    body: shop
      ? `You're next in line at ${shop}. Please head to the shop now.`
      : "You're next in line. Please head to the barbershop now.",
  };
}
