import globals from "globals";
import pluginJs from "@eslint/js";
import eslintConfigPrettier from "eslint-config-prettier";

export default [
  {
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },
    ignorePatterns: ["app/assets/builds/", "node_modules/"],
  },
  pluginJs.configs.recommended,
  eslintConfigPrettier,
];
