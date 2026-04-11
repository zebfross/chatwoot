/* global axios */
import { DataManager } from '../helper/CacheHelper/DataManager';
import ApiClient from './ApiClient';

class CacheEnabledApiClient extends ApiClient {
  constructor(resource, options = {}) {
    super(resource, options);
    this.dataManager = new DataManager(this.accountIdFromRoute);
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    throw new Error('cacheModelName is not defined');
  }

  get(cache = false) {
    if (cache) {
      return this.getFromCache();
    }

    return this.getFromNetwork();
  }

  getFromNetwork() {
    return axios.get(this.url);
  }

  // eslint-disable-next-line class-methods-use-this
  extractDataFromResponse(response) {
    return response.data.payload;
  }

  // eslint-disable-next-line class-methods-use-this
  marshallData(dataToParse) {
    return { data: { payload: dataToParse } };
  }

  async getFromCache() {
    const tag = `[CacheEnabledApiClient:${this.cacheModelName}]`;
    try {
      // IDB is not supported in Firefox private mode: https://bugzilla.mozilla.org/show_bug.cgi?id=781982
      // eslint-disable-next-line no-console
      console.log(`${tag} initDb start`);
      // Guard initDb with a timeout so a blocked/hung IndexedDB upgrade
      // can't freeze the whole fetch chain indefinitely.
      await Promise.race([
        this.dataManager.initDb(),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('initDb timeout')), 3000)
        ),
      ]);
      // eslint-disable-next-line no-console
      console.log(`${tag} initDb done`);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn(`${tag} initDb failed, falling back to network:`, err);
      return this.getFromNetwork();
    }

    // eslint-disable-next-line no-console
    console.log(`${tag} fetching cache_keys`);
    const { data } = await axios.get(
      `/api/v1/accounts/${this.accountIdFromRoute}/cache_keys`
    );
    // eslint-disable-next-line no-console
    console.log(`${tag} cache_keys response`, data);
    const cacheKeyFromApi = data.cache_keys[this.cacheModelName];
    const isCacheValid = await this.validateCacheKey(cacheKeyFromApi);
    // eslint-disable-next-line no-console
    console.log(`${tag} cache valid?`, isCacheValid);

    let localData = [];
    if (isCacheValid) {
      localData = await this.dataManager.get({
        modelName: this.cacheModelName,
      });
    }
    // eslint-disable-next-line no-console
    console.log(`${tag} local data length`, localData.length);

    if (localData.length === 0) {
      return this.refetchAndCommit(cacheKeyFromApi);
    }

    return this.marshallData(localData);
  }

  async refetchAndCommit(newKey = null) {
    const response = await this.getFromNetwork();

    try {
      await this.dataManager.initDb();

      this.dataManager.replace({
        modelName: this.cacheModelName,
        data: this.extractDataFromResponse(response),
      });

      await this.dataManager.setCacheKeys({
        [this.cacheModelName]: newKey,
      });
    } catch {
      // Ignore error
    }

    return response;
  }

  async validateCacheKey(cacheKeyFromApi) {
    if (!this.dataManager.db) {
      await this.dataManager.initDb();
    }

    const cachekey = await this.dataManager.getCacheKey(this.cacheModelName);
    return cacheKeyFromApi === cachekey;
  }
}

export default CacheEnabledApiClient;
