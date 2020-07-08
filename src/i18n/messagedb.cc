// Copyright Microsoft and Project Verona Contributors.
// SPDX-License-Identifier: MIT

#include "messagedb.h"

#include <vector>

namespace
{
  /**
   * List sub-paths of a path of a particular type (directory, files, etc).
   *
   * Usage:
   *  auto dirs = getSubPaths("/foo/bar", fs::file_type::directory);
   *  for (auto& d: dirs)
   *  {
   *    auto textFiles = getSubPaths(d, fs::file_type::character);
   *    for (auto& f: textFiles)
   *    {
   *      ...
   *    }
   *  }
   *  `path` must be a directory. Return the elements found of the same type
   *  or empty list if none.
   */
  llvm::Expected<std::vector<fs::path>>
  getSubPaths(fs::path& path, fs::file_type type)
  {
    fs::directory_entry root(path);
    if (!root.is_directory())
      return lang::languageError(
        std::string(path.c_str()) + " is not a directory");
    std::vector<fs::path> subPaths;
    for (auto& p : fs::directory_iterator(root))
    {
      if (fs::status(p).type() == type)
        subPaths.push_back(p);
    }
    return subPaths;
  }

  /**
   * Read I18n file: a list of key=value pairs exposing the translation of
   * strings.
   *
   * FIXME: Implement that
   */
  llvm::Expected<lang::MessageDB::StringMap> readI18nFile(fs::path& file)
  {
    lang::MessageDB::StringMap map;
    // Open file, read pairs, add to map...
    return map;
  }
}

namespace lang
{
  static LangKind getLang(llvm::StringRef lang)
  {
    if (lang == "en")
      return LangKind::en;
    if (lang == "pt")
      return LangKind::pt;
    if (lang == "it")
      return LangKind::it;
    assert(false && "Unknown language");
  }

  static std::string getLangDesc(LangKind lang)
  {
    switch(lang) {
      case LangKind::none:
        return "none";
      case LangKind::en:
        return "en";
      case LangKind::pt:
        return "pt";
      case LangKind::it:
        return "it";
    }
    assert(false && "Unknown language");
  }

  char LanguageError::ID = 0;
  // Create a parsing error and return
  llvm::Error languageError(llvm::StringRef desc)
  {
    return llvm::make_error<LanguageError>(desc);
  }

  llvm::Error MessageDB::readDataBase()
  {
    // First, find all available languages
    auto root = getSubPaths(rootPath, fs::file_type::directory);
    if (auto err = root.takeError())
      return err;
    if (root->empty())
      return languageError("Language root directory empty");

    // Iterate through each language and populate their own maps
    for (auto& lang : *root)
    {
      // Create new map for language if none
      auto langID = getLang(lang.c_str());
      if (strings.find(langID) == strings.end())
        strings.emplace(langID, StringMap());

      // For each language file
      auto files = getSubPaths(lang, fs::file_type::character);
      if (auto err = files.takeError())
        return err;
      for (auto& f : *files)
      {
        auto vals = readI18nFile(f);
        if (auto err = vals.takeError())
          return err;
        if (vals->empty())
          continue;

        // Add new pairs to its language map
        strings[langID].insert(vals->begin(), vals->end());
      }
    }
    return llvm::Error::success();
  }

  llvm::Expected<llvm::StringRef>
  MessageDB::getMessage(llvm::StringRef key, LangKind lang)
  {
    if (lang == LangKind::none)
      lang = defaultLanguage;
    if (strings[lang].empty())
      return languageError("No language " + getLangDesc(lang));
    auto it = strings[lang].find(key);
    if (it != strings[lang].end())
      return it->second;
    return languageError("Value for key " + key.str() + " not found on language " + getLangDesc(lang));
  }
} // namespace lang
