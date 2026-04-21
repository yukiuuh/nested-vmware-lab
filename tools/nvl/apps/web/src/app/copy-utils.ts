export async function copyTextToClipboard(text: string): Promise<void> {
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return;
    }
  } catch {
    // Fall through to the textarea-based copy path for local/non-secure contexts.
  }

  const textArea = document.createElement('textarea');
  textArea.value = text;
  textArea.setAttribute('readonly', '');
  textArea.style.position = 'fixed';
  textArea.style.inset = '0 auto auto 0';
  textArea.style.opacity = '0';

  document.body.appendChild(textArea);
  textArea.select();
  document.execCommand('copy');
  document.body.removeChild(textArea);
}

export function selectAllCopyTarget(event: KeyboardEvent): void {
  if ((!event.ctrlKey && !event.metaKey) || event.key.toLowerCase() !== 'a') {
    return;
  }

  const target = event.target;
  if (!(target instanceof HTMLTextAreaElement || target instanceof HTMLInputElement)) {
    return;
  }

  event.preventDefault();
  target.select();
}
