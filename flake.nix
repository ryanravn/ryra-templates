{
  description = "Ryra machine templates";

  outputs = { self }:
    let
      directories = builtins.readDir ./machines;
      names = builtins.filter
        (name: directories.${name} == "directory" && builtins.pathExists ./machines/${name}/catalog.nix)
        (builtins.attrNames directories);
    in {
      index = builtins.listToAttrs (map (name: {
        inherit name;
        value = (import ./machines/${name}/catalog.nix) // { directory = "machines/${name}"; };
      }) names);

      templates = builtins.mapAttrs (name: meta: {
        path = ./machines/${name};
        description = meta.summary;
        welcomeText = meta.description;
      }) self.index;
    };
}
