<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';

import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  selectedAgents: {
    type: Array,
    default: () => [],
  },
  hasErrors: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:selectedAgents']);

const { t } = useI18n();
const showDropdown = ref(false);
const searchQuery = ref('');

const agents = useMapGetter('agents/getAgents');
const currentUser = useMapGetter('getCurrentUser');

const selectedIds = computed(() => props.selectedAgents.map(a => a.id));

const filteredAgents = computed(() => {
  const allAgents = agents.value || [];
  const currentUserId = currentUser.value?.id;

  return allAgents
    .filter(agent => {
      if (agent.id === currentUserId) return false;
      if (selectedIds.value.includes(agent.id)) return false;
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
  emit('update:selectedAgents', [...props.selectedAgents, agent]);
  searchQuery.value = '';
  showDropdown.value = false;
};

const removeAgent = agentId => {
  emit(
    'update:selectedAgents',
    props.selectedAgents.filter(a => a.id !== agentId)
  );
};
</script>

<template>
  <div class="relative flex-1 px-4 py-3 overflow-y-visible">
    <div class="flex items-start w-full gap-3 min-h-7">
      <label class="text-sm font-medium text-n-slate-11 whitespace-nowrap mt-1">
        {{ t('COMPOSE_NEW_CONVERSATION.FORM.CONTACT_SELECTOR.LABEL') }}
      </label>

      <div class="flex flex-wrap items-center gap-1.5 flex-1 min-w-0">
        <div
          v-for="agent in selectedAgents"
          :key="agent.id"
          class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 ltr:pl-3 rtl:pr-3 ltr:pr-1 rtl:pl-1 min-h-7 min-w-0"
        >
          <span class="text-sm truncate text-n-slate-12">
            {{ agent.name }}
          </span>
          <Button
            variant="ghost"
            icon="i-lucide-x"
            color="slate"
            size="xs"
            @click="removeAgent(agent.id)"
          />
        </div>
        <TagInput
          placeholder="Search for agents..."
          mode="single"
          :menu-items="filteredAgents"
          :show-dropdown="showDropdown"
          :is-loading="false"
          class="flex-1 min-h-7 min-w-[120px]"
          :class="errorClass"
          :focus-on-mount="selectedAgents.length === 0"
          @input="handleInput"
          @on-click-outside="showDropdown = false"
          @add="handleSelect"
        />
      </div>
    </div>
  </div>
</template>
