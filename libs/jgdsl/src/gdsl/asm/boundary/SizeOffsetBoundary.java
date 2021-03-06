package gdsl.asm.boundary;

import gdsl.asm.Visitor;

public class SizeOffsetBoundary extends Boundary {
  private long size;
  
  public long getSize() {
    return size;
  }
  
  private long offset;
  
  public long getOffset() {
    return offset;
  }

  /**
   * @param size
   * @param offset
   */
  public SizeOffsetBoundary (long size, long offset) {
    super();
    this.size = size;
    this.offset = offset;
  }

  @Override public String toString () {
    if(offset > 0)
      return "." + offset + "/" + size;
    else
      return "/" + size;
  }

  @Override public void accept (Visitor v) {
    v.visit(this);
  }
}
