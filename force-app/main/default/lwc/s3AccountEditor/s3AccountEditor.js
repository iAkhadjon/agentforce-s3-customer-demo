import { LightningElement, api } from "lwc";

const DEFAULT_VALUE = {
  accountName: null,
  s3ObjectPath: "/accounts.json",
  bucketOverride: null,
  mockMode: false
};

const normalizeText = (value) => {
  if (value === "" || value === null || value === undefined) {
    return null;
  }

  return value.trim();
};

export default class S3AccountEditor extends LightningElement {
  _readOnly = false;
  _value = { ...DEFAULT_VALUE };

  @api
  get readOnly() {
    return this._readOnly;
  }

  set readOnly(value) {
    this._readOnly = value;
  }

  @api
  get value() {
    return this._value;
  }

  set value(value) {
    this._value = {
      ...DEFAULT_VALUE,
      ...(value || {})
    };
  }

  get accountName() {
    return this.value.accountName || "";
  }

  handleInputChange(event) {
    event.stopPropagation();

    this._value = {
      ...this._value,
      accountName: normalizeText(event.detail?.value ?? event.target.value)
    };

    this.dispatchEvent(
      new CustomEvent("valuechange", {
        detail: {
          value: this._value
        },
        bubbles: true,
        composed: true
      })
    );
  }
}
