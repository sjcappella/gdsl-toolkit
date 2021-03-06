/*
 * arbitrary.h
 *
 *  Created on: May 21, 2014
 *      Author: Julian Kranz
 */

#pragma once

#include "sexpr.h"

namespace gdsl {
namespace rreil {

class arbitrary : public sexpr {
private:
  void put(std::ostream &out);
public:
  void accept(sexpr_visitor &v);
};

}
}
