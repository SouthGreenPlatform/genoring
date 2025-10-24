You can remove this README.md file as you don't need it.

In this folder, you should place a Drupal recipe for your module, if needed.
[Drupal Recipes](https://www.drupal.org/docs/extending-drupal/drupal-recipes)
are a way to automatically install and preconfigure Drupal modules, provide
and install configuration files, entities (such as pages or menu items), and
more. Refer to online documentation for details.

The directory "RECIPENAME" should be rename to a name that should be specific
enough to avoid conflicts with other recipes (think about other GenoRing modules
as well as Drupal modules). The best approach is to either use your module
name if it does not match a Drupal module, or prefix it with "genoring_".
For consistency, it is better to use lower case letteres and underscores.
If you need more than one recipe, you can add other recipes in the "recipes"
directory and use a different name than "RECIPENAME" of course.

Recipes should be installed and uninstalled using respectively GenoRing
container hooks "enable_genoring.sh" and "disable_genoring.sh". On those
scripts, use respectively the commands:
```
genoring install_recipe modules/MODULENAME/res/recipes/RECIPENAME
```
and
```
genoring uninstall_recipe modules/MODULENAME/res/recipes/RECIPENAME
```
to install or uninstall your recipes.
