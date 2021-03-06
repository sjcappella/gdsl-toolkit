package gdsl.plugin.ui.outline;

import com.google.common.base.Objects;
import gdsl.plugin.gDSL.ConDecl;
import gdsl.plugin.gDSL.Decl;
import gdsl.plugin.gDSL.DeclExport;
import gdsl.plugin.gDSL.Model;
import gdsl.plugin.gDSL.Ty;
import gdsl.plugin.gDSL.Type;
import gdsl.plugin.gDSL.Val;
import org.eclipse.emf.common.util.EList;
import org.eclipse.xtext.ui.editor.outline.IOutlineNode;
import org.eclipse.xtext.ui.editor.outline.impl.DefaultOutlineTreeProvider;
import org.eclipse.xtext.ui.editor.outline.impl.DocumentRootNode;
import org.eclipse.xtext.xbase.lib.IterableExtensions;
import org.eclipse.xtext.xbase.lib.Procedures.Procedure1;

/**
 * Customization of the default outline structure.
 * 
 * @author Daniel Endress
 * 
 * see http://www.eclipse.org/Xtext/documentation.html#outline
 */
@SuppressWarnings("all")
public class GDSLOutlineTreeProvider extends DefaultOutlineTreeProvider {
  public boolean _isLeaf(final DeclExport e) {
    return true;
  }
  
  public boolean _isLeaf(final Val v) {
    return true;
  }
  
  public boolean _isLeaf(final ConDecl cd) {
    return true;
  }
  
  public boolean _isLeaf(final Type t) {
    Ty _value = t.getValue();
    return (!Objects.equal(_value, null));
  }
  
  /**
   * Skip the top level node
   */
  public void _createChildren(final DocumentRootNode outlineNode, final Model model) {
    EList<Decl> _decl = model.getDecl();
    final Procedure1<Decl> _function = new Procedure1<Decl>() {
      public void apply(final Decl decl) {
        GDSLOutlineTreeProvider.this.createNode(outlineNode, decl);
      }
    };
    IterableExtensions.<Decl>forEach(_decl, _function);
  }
  
  /**
   * Create constructors as the children nodes of type elements
   */
  public void _createChildren(final IOutlineNode parent, final Type type) {
    EList<ConDecl> _conDecl = type.getConDecl();
    final Procedure1<ConDecl> _function = new Procedure1<ConDecl>() {
      public void apply(final ConDecl con) {
        GDSLOutlineTreeProvider.this.createNode(parent, con);
      }
    };
    IterableExtensions.<ConDecl>forEach(_conDecl, _function);
  }
}
