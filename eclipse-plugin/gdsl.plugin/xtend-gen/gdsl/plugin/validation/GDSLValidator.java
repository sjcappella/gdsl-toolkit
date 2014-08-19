/**
 * generated by Xtext
 */
package gdsl.plugin.validation;

import com.google.common.base.Objects;
import gdsl.plugin.gDSL.CONS;
import gdsl.plugin.gDSL.GDSLPackage;
import gdsl.plugin.gDSL.Model;
import gdsl.plugin.gDSL.PAT;
import gdsl.plugin.preferences.GDSLPluginPreferences;
import gdsl.plugin.validation.AbstractGDSLValidator;
import gdsl.plugin.validation.GDSLCompilerTools;
import org.eclipse.core.resources.IContainer;
import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.IResource;
import org.eclipse.core.resources.IWorkspace;
import org.eclipse.core.resources.IWorkspaceRoot;
import org.eclipse.core.resources.ResourcesPlugin;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IPath;
import org.eclipse.emf.ecore.EAttribute;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.xtext.validation.Check;
import org.eclipse.xtext.xbase.lib.Exceptions;

/**
 * Custom validation rules.
 * 
 * see http://www.eclipse.org/Xtext/documentation.html#validation
 */
@SuppressWarnings("all")
public class GDSLValidator extends AbstractGDSLValidator {
  @Check
  public void upperCaseCons(final CONS cons) {
    String _conName = cons.getConName();
    char _charAt = _conName.charAt(0);
    boolean _isUpperCase = Character.isUpperCase(_charAt);
    boolean _not = (!_isUpperCase);
    if (_not) {
      EAttribute _cONS_ConName = GDSLPackage.eINSTANCE.getCONS_ConName();
      this.error("Constructors have to start with a capital", _cONS_ConName);
    }
  }
  
  @Check
  public void patternOnlyForConstructors(final PAT pat) {
    PAT _pat = pat.getPat();
    boolean _notEquals = (!Objects.equal(null, _pat));
    if (_notEquals) {
      String _id = pat.getId();
      char _charAt = _id.charAt(0);
      boolean _isUpperCase = Character.isUpperCase(_charAt);
      boolean _not = (!_isUpperCase);
      if (_not) {
        EReference _pAT_Pat = GDSLPackage.eINSTANCE.getPAT_Pat();
        this.error("A pattern is only allowed for constructors", _pAT_Pat);
      }
    }
  }
  
  @Check
  public void checkExternalCompiler(final Model model) {
    final Resource resource = model.eResource();
    StringBuilder commandBuilder = new StringBuilder();
    String _compilerInvocation = GDSLPluginPreferences.getCompilerInvocation();
    commandBuilder.append(_compilerInvocation);
    commandBuilder.append(" -o");
    String _outputName = GDSLPluginPreferences.getOutputName(resource);
    String _plus = (" " + _outputName);
    commandBuilder.append(_plus);
    commandBuilder.append(" --runtime=");
    String _runtimeTemplates = GDSLPluginPreferences.getRuntimeTemplates(resource);
    commandBuilder.append(_runtimeTemplates);
    final String prefix = GDSLPluginPreferences.getPrefix(resource);
    boolean _notEquals = (!Objects.equal(null, prefix));
    if (_notEquals) {
      commandBuilder.append((" --prefix=" + prefix));
    }
    boolean _isTypeCheckerEnabled = GDSLPluginPreferences.isTypeCheckerEnabled();
    if (_isTypeCheckerEnabled) {
      int _typeCheckerIteration = GDSLPluginPreferences.getTypeCheckerIteration();
      String _plus_1 = (" --maxIter=" + Integer.valueOf(_typeCheckerIteration));
      commandBuilder.append(_plus_1);
    } else {
      commandBuilder.append(" -t");
    }
    IProject _obtainProject = GDSLPluginPreferences.obtainProject(resource);
    final IPath projectPath = _obtainProject.getLocation();
    IWorkspace _workspace = ResourcesPlugin.getWorkspace();
    final IWorkspaceRoot workspaceRoot = _workspace.getRoot();
    String _recursiveGetMLFiles = this.recursiveGetMLFiles(projectPath, workspaceRoot);
    commandBuilder.append(_recursiveGetMLFiles);
    String _string = commandBuilder.toString();
    GDSLCompilerTools.compileAndSetMarkers(_string, projectPath);
  }
  
  /**
   * Builds a string containing all files found under the specified path with the extension .ml
   * 
   * @param path
   * 			The path to search for files
   * @param root
   * 			The workspace root (ResourcesPlugin.getWorkspace().getRoot())
   * @return
   * 			A string containing all the files found separated by a space
   */
  private String recursiveGetMLFiles(final IPath path, final IWorkspaceRoot root) {
    final IContainer container = root.getContainerForLocation(path);
    StringBuilder result = new StringBuilder();
    try {
      IResource[] _members = container.members();
      for (final IResource r : _members) {
        {
          String _fileExtension = r.getFileExtension();
          boolean _equals = "ml".equals(_fileExtension);
          if (_equals) {
            IPath _location = r.getLocation();
            String _oSString = _location.toOSString();
            String _plus = (" " + _oSString);
            result.append(_plus);
          }
          int _type = r.getType();
          boolean _equals_1 = (_type == IResource.FOLDER);
          if (_equals_1) {
            IPath _location_1 = r.getLocation();
            String _recursiveGetMLFiles = this.recursiveGetMLFiles(_location_1, root);
            result.append(_recursiveGetMLFiles);
          }
        }
      }
    } catch (final Throwable _t) {
      if (_t instanceof CoreException) {
        final CoreException e = (CoreException)_t;
      } else {
        throw Exceptions.sneakyThrow(_t);
      }
    }
    return result.toString();
  }
}
