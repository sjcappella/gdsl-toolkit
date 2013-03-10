package rreil.operation;

import rreil.linear.LinearExpression;

public class ShiftRightSignedOperation extends BinaryOperation {

	public ShiftRightSignedOperation(long size, LinearExpression operand1,
			LinearExpression operand2) {
		super(size, operand1, operand2);
	}
	
	@Override
	public String toString() {
		return operand1 + " >>s:" + size + " " + operand2;
	}
}
