
/*
 * store.cpp
 *
 *  Created on: May 21, 2014
 *      Author: Julian Kranz
 */

#include <cppgdsl/rreil/statement/store.h>
#include <iostream>

gdsl::rreil::store::store(int_t size, address *_address, linear *rhs) {
  this->size = size;
  this->_address = _address;
  this->rhs = rhs;
}

gdsl::rreil::store::~store() {
  delete this->_address;
  delete this->rhs;
}

void gdsl::rreil::store::accept(statement_visitor &v) {
  v.visit(this);
}

void gdsl::rreil::store::put(std::ostream &out) const {
  out << "*" << *_address << " =:" << size << " " << *rhs;
}
