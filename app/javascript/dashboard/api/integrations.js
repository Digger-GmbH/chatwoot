/* global axios */

import ApiClient from './ApiClient';

class IntegrationsAPI extends ApiClient {
  constructor() {
    super('integrations/apps', { accountScoped: true });
  }

  connectSlack(code) {
    return axios.post(`${this.baseUrl()}/integrations/slack`, { code });
  }

  updateSlack({ referenceId, messageMode }) {
    return axios.patch(`${this.baseUrl()}/integrations/slack`, {
      reference_id: referenceId,
      message_mode: messageMode,
    });
  }

  listAllSlackChannels() {
    return axios.get(`${this.baseUrl()}/integrations/slack/list_all_channels`);
  }

  delete(integrationId) {
    return axios.delete(`${this.baseUrl()}/integrations/${integrationId}`);
  }

  createHook(hookData) {
    return axios.post(`${this.baseUrl()}/integrations/hooks`, hookData);
  }

  deleteHook(hookId) {
    return axios.delete(`${this.baseUrl()}/integrations/hooks/${hookId}`);
  }

  connectShopify({ shopDomain }) {
    return axios.post(`${this.baseUrl()}/integrations/shopify/auth`, {
      shop_domain: shopDomain,
    });
  }

  getShopifyCredentials() {
    return axios.get(`${this.baseUrl()}/integrations/shopify/credentials`);
  }

  updateShopifyCredentials({ clientId, clientSecret }) {
    return axios.put(`${this.baseUrl()}/integrations/shopify/credentials`, {
      client_id: clientId,
      client_secret: clientSecret,
    });
  }

  deleteShopifyCredentials() {
    return axios.delete(`${this.baseUrl()}/integrations/shopify/credentials`);
  }
}

export default new IntegrationsAPI();
