import ApiClient from './ApiClient';

class InternalContactsAPI extends ApiClient {
  constructor() {
    super('internal_contacts', { accountScoped: true });
  }
}

export default new InternalContactsAPI();
