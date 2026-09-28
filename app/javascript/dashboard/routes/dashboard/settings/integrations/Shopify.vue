<script setup>
import { ref, computed, onMounted } from 'vue';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Integration from './Integration.vue';
import integrationAPI from 'dashboard/api/integrations';

import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

defineProps({
  error: {
    type: String,
    default: '',
  },
});

const store = useStore();
const { t } = useI18n();
const dialogRef = ref(null);
const clearCredentialsDialogRef = ref(null);
const integrationLoaded = ref(false);
const storeUrl = ref('');
const isSubmitting = ref(false);
const storeUrlError = ref('');
const integration = useFunctionGetter('integrations/getIntegration', 'shopify');
const uiFlags = useMapGetter('integrations/getUIFlags');

const clientId = ref('');
const clientSecret = ref('');
const credentialsSource = ref(null);
const clientSecretConfigured = ref(false);
const globalFallbackAvailable = ref(false);
const isLoadingCredentials = ref(false);
const isSavingCredentials = ref(false);
const isClearingCredentials = ref(false);
const credentialsError = ref('');

const integrationAction = computed(() => {
  if (integration.value.enabled) {
    return 'disconnect';
  }
  return 'connect';
});

const canConnectStore = computed(
  () =>
    credentialsSource.value === 'account' ||
    credentialsSource.value === 'global'
);

const credentialsSourceLabel = computed(() => {
  if (credentialsSource.value === 'account') {
    return t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.SOURCE.ACCOUNT');
  }
  if (credentialsSource.value === 'global') {
    return t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.SOURCE.GLOBAL');
  }
  return t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.SOURCE.NONE');
});

const clientSecretHelp = computed(() => {
  if (clientSecretConfigured.value && !clientSecret.value) {
    return t(
      'INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLIENT_SECRET.CONFIGURED_HELP'
    );
  }
  return t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLIENT_SECRET.HELP');
});

const hideStoreUrlModal = () => {
  storeUrl.value = '';
  storeUrlError.value = '';
  isSubmitting.value = false;
};

const validateStoreUrl = url => {
  const pattern =
    /^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.myshopify\.(?:com|io)$/i;
  return pattern.test(url);
};

const openStoreUrlDialog = () => {
  if (!canConnectStore.value) {
    useAlert(
      t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.REQUIRED_BEFORE_CONNECT')
    );
    return;
  }
  if (dialogRef.value) {
    dialogRef.value.open();
  }
};

const loadCredentials = async () => {
  try {
    isLoadingCredentials.value = true;
    credentialsError.value = '';
    const { data } = await integrationAPI.getShopifyCredentials();
    clientId.value = data.client_id || '';
    clientSecret.value = '';
    clientSecretConfigured.value = Boolean(data.client_secret_configured);
    credentialsSource.value = data.source;
    globalFallbackAvailable.value = Boolean(data.global_fallback_available);
  } catch (error) {
    credentialsError.value = t(
      'INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.LOAD_ERROR'
    );
  } finally {
    isLoadingCredentials.value = false;
  }
};

const handleSaveCredentials = async () => {
  credentialsError.value = '';
  if (!clientId.value.trim()) {
    credentialsError.value = t(
      'INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.VALIDATION.CLIENT_ID'
    );
    return;
  }
  if (!clientSecretConfigured.value && !clientSecret.value.trim()) {
    credentialsError.value = t(
      'INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.VALIDATION.CLIENT_SECRET'
    );
    return;
  }

  try {
    isSavingCredentials.value = true;
    const { data } = await integrationAPI.updateShopifyCredentials({
      clientId: clientId.value.trim(),
      clientSecret: clientSecret.value,
    });
    clientId.value = data.client_id || '';
    clientSecret.value = '';
    clientSecretConfigured.value = Boolean(data.client_secret_configured);
    credentialsSource.value = data.source;
    globalFallbackAvailable.value = Boolean(data.global_fallback_available);
    useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.SAVE_SUCCESS'));
  } catch (error) {
    credentialsError.value =
      error.response?.data?.error ||
      t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.SAVE_ERROR');
  } finally {
    isSavingCredentials.value = false;
  }
};

const openClearCredentialsDialog = () => {
  if (clearCredentialsDialogRef.value) {
    clearCredentialsDialogRef.value.open();
  }
};

const handleClearCredentials = async () => {
  try {
    isClearingCredentials.value = true;
    await integrationAPI.deleteShopifyCredentials();
    await loadCredentials();
    useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLEAR_SUCCESS'));
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLEAR_ERROR'));
  } finally {
    isClearingCredentials.value = false;
  }
};

const handleStoreUrlSubmit = async () => {
  try {
    storeUrlError.value = '';
    if (!validateStoreUrl(storeUrl.value)) {
      storeUrlError.value = t(
        'INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.INVALID_URL'
      );
      return;
    }

    isSubmitting.value = true;
    const { data } = await integrationAPI.connectShopify({
      shopDomain: storeUrl.value,
    });

    if (data.redirect_url) {
      window.location.href = data.redirect_url;
    }
  } catch (error) {
    storeUrlError.value =
      error.response?.data?.error ||
      error.message ||
      t('INTEGRATION_SETTINGS.SHOPIFY.ERROR');
  } finally {
    isSubmitting.value = false;
  }
};

const initializeShopifyIntegration = async () => {
  await Promise.all([
    store.dispatch('integrations/get', 'shopify'),
    loadCredentials(),
  ]);
  integrationLoaded.value = true;
};

onMounted(() => {
  initializeShopifyIntegration();
});
</script>

<template>
  <SettingsLayout :is-loading="!integrationLoaded || uiFlags.isCreatingShopify">
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_SETTINGS.SHOPIFY.HEADER')"
        description=""
        feature-name="shopify_integration"
        :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-6">
        <section
          class="flex flex-col gap-4 rounded-xl bg-n-solid-2 p-6 outline outline-1 outline-n-container"
        >
          <div class="flex flex-col gap-1">
            <h3 class="text-base font-medium text-n-slate-12">
              {{ t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.TITLE') }}
            </h3>
            <p class="text-sm text-n-slate-11">
              {{ t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.DESCRIPTION') }}
            </p>
            <p class="text-sm text-n-slate-10">
              {{ credentialsSourceLabel }}
            </p>
            <p
              v-if="globalFallbackAvailable && credentialsSource === 'account'"
              class="text-sm text-n-slate-10"
            >
              {{
                t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.GLOBAL_FALLBACK')
              }}
            </p>
          </div>

          <div class="flex flex-col gap-4 max-w-xl">
            <Input
              v-model="clientId"
              :label="
                t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLIENT_ID.LABEL')
              "
              :placeholder="
                t(
                  'INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLIENT_ID.PLACEHOLDER'
                )
              "
              :message="
                t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLIENT_ID.HELP')
              "
              :disabled="isLoadingCredentials || isSavingCredentials"
            />
            <Input
              v-model="clientSecret"
              type="password"
              :label="
                t(
                  'INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLIENT_SECRET.LABEL'
                )
              "
              :placeholder="
                t(
                  'INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLIENT_SECRET.PLACEHOLDER'
                )
              "
              :message="clientSecretHelp"
              :disabled="isLoadingCredentials || isSavingCredentials"
            />
            <p v-if="credentialsError" class="text-sm text-n-ruby-9">
              {{ credentialsError }}
            </p>
            <div class="flex flex-wrap gap-2">
              <Button
                teal
                :label="t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.SAVE')"
                :is-loading="isSavingCredentials"
                :disabled="isLoadingCredentials || isClearingCredentials"
                @click="handleSaveCredentials"
              />
              <Button
                v-if="credentialsSource === 'account'"
                slate
                faded
                :label="t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLEAR')"
                :is-loading="isClearingCredentials"
                :disabled="isLoadingCredentials || isSavingCredentials"
                @click="openClearCredentialsDialog"
              />
            </div>
          </div>
        </section>

        <Integration
          :integration-id="integration.id"
          :integration-logo="integration.logo"
          :integration-name="integration.name"
          :integration-description="integration.description"
          :integration-enabled="integration.enabled"
          :integration-action="integrationAction"
          :delete-confirmation-text="{
            title: t('INTEGRATION_SETTINGS.SHOPIFY.DELETE.TITLE'),
            message: t('INTEGRATION_SETTINGS.SHOPIFY.DELETE.MESSAGE'),
          }"
        >
          <template #action>
            <Button
              teal
              :label="t('INTEGRATION_SETTINGS.CONNECT.BUTTON_TEXT')"
              :disabled="!canConnectStore"
              @click="openStoreUrlDialog"
            />
          </template>
        </Integration>
        <div
          v-if="error"
          class="flex items-center justify-center flex-1 outline outline-n-container outline-1 bg-n-alpha-3 rounded-md shadow p-6"
        >
          <p class="text-n-ruby-9">
            {{ t('INTEGRATION_SETTINGS.SHOPIFY.ERROR') }}
          </p>
        </div>
        <Dialog
          ref="dialogRef"
          :title="t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.TITLE')"
          :is-loading="isSubmitting"
          @confirm="handleStoreUrlSubmit"
          @close="hideStoreUrlModal"
        >
          <Input
            v-model="storeUrl"
            :label="t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.LABEL')"
            :placeholder="
              t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.PLACEHOLDER')
            "
            :message="
              !storeUrlError
                ? t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.HELP')
                : storeUrlError
            "
            :message-type="storeUrlError ? 'error' : 'info'"
          />
        </Dialog>
        <Dialog
          ref="clearCredentialsDialogRef"
          :title="t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLEAR')"
          :is-loading="isClearingCredentials"
          @confirm="handleClearCredentials"
        >
          <p class="text-sm text-n-slate-11">
            {{ t('INTEGRATION_SETTINGS.SHOPIFY.CREDENTIALS.CLEAR_CONFIRM') }}
          </p>
        </Dialog>
      </div>
    </template>
  </SettingsLayout>
</template>
