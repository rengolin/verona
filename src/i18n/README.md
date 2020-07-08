# Internationalisation

This is a simple implementation of internationalisation efforts to translate
and localise the project.

Translation files are available at the root directory `/i18n/<lang>/*.txt` with
keys (in English) and values (in the respective language). Translating to a new
language is just a matter of creating a new directory, copying the files from
another language and translating them.

## Implementation details

The idea is to have a common class to the whole project which can be used to
translate any user-interface messages or locale-specific outpus (such as dates,
currency, number formats) based on the active locale or a command line option.

Languages that don't have a specific key in their translation files will get
English output. Any formatting in the messages must be identical in every
language, and none of the variables can be language-specific, so in case where
they need to be translated, we need distinct keys.

To make easy for programmers and translators, we need to have a few tools and
processes regarding internationalisation:

* A tool to identify how many keys are translated in each language, in reference
to the base language. There should be no keys in other languages that don't
exist in the base language.
* A tool to verify that every localised string has the same number of parameters
than the base language.
* A process in which to build a database (as simple as a list of files in an
installation directory), so the translations and localisations can be together
with the production binaries.
* A runtime process to identify the locale and search for specific translation
files (ex. pt_BR). Failing that, search for the generic language (ex. pt) and
failing that, use the base language (ex. en).

Note that the base language does not need to be English. It can be selected as
a parameter of the initialisation of the language class, as long as there is a
translation directory for it and that language has the same or more keys than
every other. Use the language verification tool to make sure the language
adheres to the requirements.

## Code structure

The class is meant to be a global context for localisation. Depending on the use
it can be a global variable, a class-context variable constructed with the class
or a variable that is passed along functions as arguments.

The class can have a number of static methods, to bypass locale settings and
interface with users in a specific way. It should also have an internal context
where the locale options are stored, and print methods make use of them.
