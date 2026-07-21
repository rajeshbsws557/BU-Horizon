const SAFE_ORIGIN = "https://admin.invalid";
const UNSAFE_PATH_CHARACTERS =
  /\\|%(?:2f|5c|00|0[0-9a-f]|1[0-9a-f]|7f)|[\u0000-\u001f\u007f]/i;

export function safeNextPath(value: string | null | undefined): string {
  if (
    !value ||
    !value.startsWith("/") ||
    value.startsWith("//") ||
    UNSAFE_PATH_CHARACTERS.test(value)
  ) {
    return "/";
  }

  try {
    const parsed = new URL(value, SAFE_ORIGIN);
    if (parsed.origin !== SAFE_ORIGIN) return "/";
    return `${parsed.pathname}${parsed.search}${parsed.hash}`;
  } catch {
    return "/";
  }
}
