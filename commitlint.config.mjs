export default {
  extends: ["@commitlint/config-conventional"],
  ignores: [(commit) => /^\[(Release|Fix|Feat|Doc|Chore)\]/i.test(commit)],
};
