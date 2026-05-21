import { LightningElement, api } from "lwc";
import lookupAccounts from "@salesforce/apex/S3AccountAgentAction.lookupAccounts";

const fallback = (value) => {
  if (value === null || value === undefined || value === "") {
    return "Not provided";
  }

  return value;
};

const DEFAULT_MINIMUM_LOADING_MS = 1000;
const MAX_LOADING_SECONDS = 600;

const normalizeDelay = (value, fallbackValue = DEFAULT_MINIMUM_LOADING_MS) => {
  const numericValue = Number(value);

  if (!Number.isFinite(numericValue)) {
    return fallbackValue;
  }

  return Math.max(Math.round(numericValue), 0);
};

export default class S3AccountRenderer extends LightningElement {
  _minimumLoadingMs = DEFAULT_MINIMUM_LOADING_MS;
  _payload = null;
  _rawValue;
  requestToken = 0;

  accountName = "";
  loadingTimeSeconds = String(DEFAULT_MINIMUM_LOADING_MS / 1000);
  isLocalLoading = false;
  isValueLoading = false;
  hasRenderedPayload = false;

  @api
  get value() {
    return this._rawValue;
  }

  set value(rawValue) {
    this._rawValue = rawValue;
    this.applyExternalValue(rawValue);
  }

  @api
  get minimumLoadingMs() {
    return this._minimumLoadingMs;
  }

  set minimumLoadingMs(value) {
    this._minimumLoadingMs = normalizeDelay(value);
    this.loadingTimeSeconds = String(this._minimumLoadingMs / 1000);
  }

  get payload() {
    return this._payload;
  }

  get isLoading() {
    return (
      this.isLocalLoading ||
      this.isValueLoading ||
      this._rawValue?.loading === true ||
      this._rawValue?.isLoading === true
    );
  }

  get hasPayload() {
    return this.payload !== null && this.payload !== undefined;
  }

  get hasResultContent() {
    return (
      this.hasPayload &&
      (this.hasError || this.hasAccounts || this.message !== "")
    );
  }

  get isSubmitDisabled() {
    return this.isLocalLoading || this.accountName.trim() === "";
  }

  get submitLabel() {
    return this.isLocalLoading ? "Loading" : "Submit";
  }

  get hasError() {
    return !this.isLoading && this.payload?.success === false;
  }

  get message() {
    return this.payload?.message || "";
  }

  get errorMessage() {
    return this.message || "Unable to retrieve account data.";
  }

  get accounts() {
    const payload = this.payload;

    if (Array.isArray(payload?.accounts)) {
      return payload.accounts;
    }

    if (payload?.account) {
      return [
        {
          ...payload.account,
          contacts: Array.isArray(payload?.contacts)
            ? payload.contacts
            : payload.account.contacts
        }
      ];
    }

    return [];
  }

  get accountCards() {
    return this.accounts.map((account, index) => {
      const contacts = Array.isArray(account.contacts) ? account.contacts : [];
      const websiteUrl = account.website || "";

      return {
        key: account.id || `${account.name || "account"}-${index}`,
        name: fallback(account.name),
        industry: fallback(account.industry),
        phone: fallback(account.phone),
        website: fallback(websiteUrl),
        websiteUrl,
        hasWebsite: websiteUrl !== "",
        contactRows: contacts.map((contact, contactIndex) => ({
          id: contact.id || `${contact.email || "contact"}-${contactIndex}`,
          firstName: fallback(contact.firstName),
          lastName: fallback(contact.lastName),
          fullName: this.formatContactName(contact),
          email: fallback(contact.email),
          emailHref: contact.email ? `mailto:${contact.email}` : "#",
          title: fallback(contact.title)
        })),
        hasContacts: contacts.length > 0
      };
    });
  }

  formatContactName(contact) {
    const nameParts = [contact.firstName, contact.lastName].filter(
      (value) => value !== null && value !== undefined && value !== ""
    );

    return nameParts.length > 0 ? nameParts.join(" ") : "Not provided";
  }

  get hasAccounts() {
    return this.accountCards.length > 0;
  }

  get effectiveMinimumLoadingMs() {
    return normalizeDelay(
      Number(this.loadingTimeSeconds) * 1000,
      this._minimumLoadingMs
    );
  }

  handleAccountNameChange(event) {
    this.accountName = event.detail?.value ?? event.target.value;
  }

  handleLoadingTimeChange(event) {
    const requestedSeconds = Number(event.detail?.value ?? event.target.value);

    if (!Number.isFinite(requestedSeconds)) {
      return;
    }

    const normalizedSeconds = Math.min(
      Math.max(requestedSeconds, 0),
      MAX_LOADING_SECONDS
    );
    this.loadingTimeSeconds = String(normalizedSeconds);
    this._minimumLoadingMs = Math.round(normalizedSeconds * 1000);
  }

  async handleLookupSubmit(event) {
    event.preventDefault();

    const requestedAccountName = this.accountName.trim();
    if (requestedAccountName === "" || this.isLocalLoading) {
      return;
    }

    const token = ++this.requestToken;
    const startedAt = Date.now();
    this.accountName = requestedAccountName;
    this._payload = null;
    this.isValueLoading = false;
    this.isLocalLoading = true;

    try {
      const response = await lookupAccounts({
        accountName: requestedAccountName
      });
      await this.waitForMinimumLoading(startedAt);

      if (this.requestToken === token) {
        this._payload = response;
        this.hasRenderedPayload = true;
      }
    } catch (error) {
      await this.waitForMinimumLoading(startedAt);

      if (this.requestToken === token) {
        this._payload = this.buildErrorPayload(error);
        this.hasRenderedPayload = true;
      }
    } finally {
      if (this.requestToken === token) {
        this.isLocalLoading = false;
      }
    }
  }

  applyExternalValue(rawValue) {
    const token = ++this.requestToken;
    this.isLocalLoading = false;

    if (rawValue?.loading === true || rawValue?.isLoading === true) {
      this._payload = null;
      this.isValueLoading = true;
      return;
    }

    if (rawValue === undefined) {
      this._payload = null;
      this.isValueLoading = false;
      this.hasRenderedPayload = false;
      return;
    }

    const payload = this.unwrapPayload(rawValue);

    if (!payload) {
      this._payload = null;
      this.isValueLoading = false;
      this.hasRenderedPayload = false;
      return;
    }

    this.applyPayloadAfterMinimumLoading(payload, token);
  }

  async applyPayloadAfterMinimumLoading(payload, token) {
    const startedAt = Date.now();
    this._payload = null;
    this.isValueLoading = true;

    await this.waitForMinimumLoading(startedAt);

    if (this.requestToken === token) {
      this._payload = payload;
      this.hasRenderedPayload = true;
      this.isValueLoading = false;
    }
  }

  waitForMinimumLoading(startedAt) {
    const elapsedMs = Date.now() - startedAt;
    const remainingMs = Math.max(this.effectiveMinimumLoadingMs - elapsedMs, 0);

    if (remainingMs === 0) {
      return Promise.resolve();
    }

    return new Promise((resolve) => {
      setTimeout(resolve, remainingMs);
    });
  }

  buildErrorPayload(error) {
    return {
      success: false,
      message: this.reduceError(error),
      accounts: [],
      contacts: []
    };
  }

  reduceError(error) {
    if (Array.isArray(error?.body)) {
      return error.body.map((entry) => entry.message).join(", ");
    }

    if (typeof error?.body?.message === "string") {
      return error.body.message;
    }

    if (typeof error?.message === "string") {
      return error.message;
    }

    return "The account and contact information could not be retrieved.";
  }

  unwrapPayload(rawValue) {
    if (Array.isArray(rawValue)) {
      return rawValue.length > 0 ? this.unwrapPayload(rawValue[0]) : null;
    }

    if (!rawValue || typeof rawValue !== "object") {
      return null;
    }

    if (rawValue.accountData) {
      return rawValue.accountData;
    }

    if (rawValue.response?.accountData) {
      return rawValue.response.accountData;
    }

    if (
      "success" in rawValue ||
      "account" in rawValue ||
      "accounts" in rawValue ||
      "contacts" in rawValue ||
      "message" in rawValue
    ) {
      return rawValue;
    }

    return null;
  }
}
