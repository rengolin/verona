// Copyright Microsoft and Project Verona Contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include "llvm/Support/Error.h"

#include <filesystem>
#include <map>
#include <string>

namespace fs = std::filesystem;

namespace lang
{
  /**
   * LanguageError: Errors reading files, finding languages, printing messages.
   *
   * FIXME: Bootstrap translated messages in some form to avoid chicken and egg
   * problem of how to handle errors befor selecting a language. For now, we
   * default to English.
   */
  class LanguageError : llvm::ErrorInfo<LanguageError>
  {
    // FIXME: Shouldn't this be wstring? llvm::StringRef can't cope with it.
    std::string desc;

  public:
    static char ID;
    LanguageError(llvm::StringRef desc) : desc(desc) {}
    void log(llvm::raw_ostream& OS) const override
    {
      OS << desc;
    }
    std::error_code convertToErrorCode() const override
    {
      return llvm::inconvertibleErrorCode();
    }
  };
  // Create a parsing error and return
  llvm::Error languageError(llvm::StringRef desc);

  /**
   * ID of the language, for selection process with indexed access.
   * FIXME: Use proper locale logic here.
   */
  enum class LangKind
  {
    none = 0,
    en,
    pt,
    it
  };

  /**
   * Message Database: collects all languages and organise them by id.
   *
   * Returns wide-char messages for the specified languages, given
   * a message-id.
   *
   * Each language directory has files with message-id="translated string"
   * lines, and they will be scanned at construction of this class.
   *
   * Users just need to request a message id, and the message in the
   * detected language will be retrieved. The language can be overriden at
   * run time.
   *
   * TODO: This class should be used by a wider localisation class that knows
   * about locales for more than just language (date, number, etc).
   */
  class MessageDB
  {
  public:
    /// Key/Value type for each language ({"msg1" -> "hello world",...})
    using StringMap = std::map<std::string, std::string>;
    /// Map of languages type ({"en" -> { ... }, "pt" -> { ... }, ...}))
    using LanguageMap = std::map<LangKind, StringMap>;

    /// Public stactic constructor to allow for error handling
    static llvm::Expected<MessageDB>
    CreateMessageDB(LangKind lang, llvm::StringRef path)
    {
      auto mdb = MessageDB(lang, path);
      if (!mdb.readDataBase())
        return languageError("Cannot read languages database");
      return mdb;
    }

    /**
     * Gets a message, by key, on a specific language (if passed) or in the
     * default language (when the object was created).
     */
    llvm::Expected<llvm::StringRef>
    getMessage(llvm::StringRef key, LangKind lang = LangKind::none);

  private:
    LangKind defaultLanguage;
    fs::path rootPath;
    /// Map of all languages and respective strings
    LanguageMap strings;

    /// Populate the database with all found languages and strings
    llvm::Error readDataBase();
    /// Private constructor, used only by the public static method
    MessageDB(LangKind lang, llvm::StringRef path)
    : defaultLanguage(lang), rootPath(path)
    {}
  };

} // namespace lang
