"use client";

import { AlertTriangle, X } from "lucide-react";

import { useDialogFocus } from "@/hooks/use-dialog-focus";

import styles from "./entity.module.css";

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description: string;
  confirmLabel: string;
  dangerous?: boolean;
  busy?: boolean;
  onConfirm: () => void;
  onClose: () => void;
}

export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel,
  dangerous = false,
  busy = false,
  onConfirm,
  onClose,
}: ConfirmDialogProps) {
  const dialogRef = useDialogFocus<HTMLDivElement>(
    open,
    busy ? undefined : onClose,
  );

  if (!open) return null;

  return (
    <div className={styles.dialogBackdrop} role="presentation" onMouseDown={onClose}>
      <div
        aria-labelledby="confirm-dialog-title"
        aria-modal="true"
        className={styles.confirmDialog}
        onMouseDown={(event) => event.stopPropagation()}
        ref={dialogRef}
        role="alertdialog"
        tabIndex={-1}
      >
        <button aria-label="Close" className={styles.iconButton} onClick={onClose}>
          <X size={18} />
        </button>
        <span className={dangerous ? styles.dangerIcon : styles.warningIcon}>
          <AlertTriangle size={22} />
        </span>
        <h2 id="confirm-dialog-title">{title}</h2>
        <p>{description}</p>
        <div className={styles.confirmActions}>
          <button
            className={styles.secondaryButton}
            data-dialog-initial-focus
            disabled={busy}
            onClick={onClose}
          >
            Cancel
          </button>
          <button
            className={dangerous ? styles.dangerButton : styles.primaryButton}
            disabled={busy}
            onClick={onConfirm}
          >
            {busy ? "Working…" : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
