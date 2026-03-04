<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';

import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  selectedAgent: {
    type: Object,
    default: null,
  },
  hasErrors: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['selectAgent', 'clearAgent']);

const { t } = useI18n();
const showDropdown = ref(false);
const searchQuery = ref('');

const agents = useMapGetter('agents/getAgents');
const currentUser = useMapGetter('getCurrentUser');

const filteredAgents = computed(() => {
  const allAgents = agents.value || [];
  const currentUserId = currentUser.value?.id;

  return allAgents
    .filter(agent => {
      if (agent.id === currentUserId) return false;
      if (!searchQuery.value) return true;
      const query = searchQuery.value.toLowerCase();
      return (
        (agent.name || '').toLowerCase().includes(query) ||
        (agent.email || '').toLowerCase().includes(query)
      );
    })
    .map(agent => ({
      id: agent.id,
      label: agent.name,
      value: agent.id,
      thumbnail: { name: agent.name, src: agent.thumbnail },
      name: agent.name,
      email: agent.email,
      action: 'agent',
    }));
});

const selectedAgentLabel = computed(() => {
  if (!props.selectedAgent) return '';
  return props.selectedAgent.name || '';
});

const errorClass = computed(() => {
  return props.hasErrors
    ? '[&_input]:placeholder:!text-n-ruby-9 [&_input]:dark:placeholder:!text-n-ruby-9'
    : '';
});

const handleInput = value => {
  searchQuery.value = value;
  showDropdown.value = true;
};

const handleSelect = agent => {
  emit('selectAgent', agent);
  showDropdown.value = false;
};
</script>

<template>
  <div class="relative flex-1 px-4 py-3 overflow-y-visible">
    <div class="flex items-baseline w-full gap-3 min-h-7">
      <label class="text-sm font-medium text-n-slate-11 whitespace-nowrap">
        {{ t('COMPOSE_NEW_CONVERSATION.FORM.CONTACT_SELECTOR.LABEL') }}
      </label>

      <div
        v-if="selectedAgent"
        class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 ltr:pl-3 rtl:pr-3 ltr:pr-1 rtl:pl-1 min-h-7 min-w-0"
      >
        <span class="text-sm truncate text-n-slate-12">
          {{ selectedAgentLabel }}
        </span>
        <Button
          variant="ghost"
          icon="i-lucide-x"
          color="slate"
          size="xs"
          @click="emit('clearAgent')"
        />
      </div>
      <TagInput
        v-else
        placeholder="Search for an agent..."
        mode="single"
        :menu-items="filteredAgents"
        :show-dropdown="showDropdown"
        :is-loading="false"
        class="flex-1 min-h-7"
        :class="errorClass"
        focus-on-mount
        @input="handleInput"
        @on-click-outside="showDropdown = false"
        @add="handleSelect"
      />
    </div>
  </div>
</template>
