/**
 * Flutter web (CanvasKit) paints to canvas; visible strings often live only on
 * [aria-label] inside open shadow roots. Cypress body.innerText misses them.
 */

export function getFlutterAccessibleText(doc) {
  if (!doc?.body) {
    return "";
  }
  const parts = [];
  const seen = new Set();

  function walk(node) {
    if (!node || seen.has(node)) {
      return;
    }
    seen.add(node);

    if (node.nodeType === Node.DOCUMENT_FRAGMENT_NODE) {
      for (const c of node.childNodes) {
        walk(c);
      }
      return;
    }

    if (node.nodeType === Node.ELEMENT_NODE) {
      const el = node;
      const al = el.getAttribute?.("aria-label");
      if (al) {
        parts.push(al);
      }
      // Also check for other accessibility attributes
      const role = el.getAttribute?.("role");
      if (role) {
        parts.push(`role: ${role}`);
      }
      const id = el.getAttribute?.("id");
      if (id) {
        parts.push(`id: ${id}`);
      }
      if (el.shadowRoot) {
        walk(el.shadowRoot);
      }
      for (const c of el.childNodes) {
        walk(c);
      }
      return;
    }

    if (node.nodeType === Node.TEXT_NODE) {
      const t = node.textContent?.trim();
      if (t) {
        parts.push(t);
      }
    }
  }

  walk(doc.body);
  const inner = doc.body.innerText?.trim();
  if (inner) {
    parts.push(inner);
  }

  return parts.join("\n");
}
