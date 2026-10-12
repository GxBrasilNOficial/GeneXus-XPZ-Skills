// Fixture sintetica minima para o E2E in-repo dos wrappers MSBuild GeneXus.
// Os wrappers refletem Genexus.MsBuild.Tasks.dll (tipos Export/Import + propriedades publicas)
// ANTES de invocar o MSBuild. Esta classe reproduz apenas a superficie exigida pela reflexao,
// para que o E2E alcance o MSBuild falso sem a instalacao real do GeneXus.
namespace Genexus.MsBuild.Tasks
{
    public class Export
    {
        public string Objects { get; set; }
        public string DependencyType { get; set; }
        public string ReferenceType { get; set; }
        public string ExportAll { get; set; }
        public string ExportKBInfo { get; set; }
    }

    public class Import
    {
        public string File { get; set; }
        public string AutomaticBackup { get; set; }
        public string ImportType { get; set; }
        public string LanguageTranslations { get; set; }
        public string RedefineExternalPrograms { get; set; }
        public string IncludeItems { get; set; }
        public string ExcludeItems { get; set; }
        public string PreviewMode { get; set; }
        public string UpdateFile { get; set; }
        public string ImportKBInformation { get; set; }
    }
}
