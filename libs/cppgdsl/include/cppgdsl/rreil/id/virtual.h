/*
 * virtual.h
 *
 *  Created on: May 21, 2014
 *      Author: Julian Kranz
 */

#pragma once
#include "id.h"
#include <string>
extern "C" {
#include <gdsl_generic.h>
}

namespace gdsl {
namespace rreil {

class _virtual : public id {
private:
  int_t t;

  void put(std::ostream &out);
public:
  _virtual(int_t t);

  int_t get_t();

  void accept(id_visitor &v);
};

}  // namespace rreil
} // namespace gdsl