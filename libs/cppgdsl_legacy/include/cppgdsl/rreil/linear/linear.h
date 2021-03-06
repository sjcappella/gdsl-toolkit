/*
 * linear.h
 *
 *  Created on: May 21, 2014
 *      Author: Julian Kranz
 */

#pragma once
#include "linear_visitor.h"
#include <iosfwd>
#include <string>

namespace gdsl {
namespace rreil {

class linear {
private:
  virtual void put(std::ostream &out) = 0;

public:
  virtual ~linear() {
  }

  std::string to_string();
  friend std::ostream &operator<< (std::ostream &out, linear &_this);

  virtual void accept(linear_visitor &v) = 0;
};

std::ostream& operator<<(std::ostream &out, linear &_this);

}
}

#include "linear_visitor.h"
#include "lin_var.h"
#include "lin_scale.h"
#include "lin_imm.h"
#include "lin_binop.h"
#include "binop_lin_op.h"
