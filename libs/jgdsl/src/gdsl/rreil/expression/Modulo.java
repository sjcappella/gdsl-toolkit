package gdsl.rreil.expression;

import gdsl.rreil.linear.LinearExpression;
import gdsl.rreil.expression.Binary;

public class Modulo extends Binary {

	public Modulo(LinearExpression operand1, LinearExpression operand2) {
		super(operand1, operand2);
	}

	@Override
	public String toString() {
		return operand1 + " % " + operand2;
	}
}
