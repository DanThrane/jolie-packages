/***************************************************************************
 *   Copyright (C) 2011 by Claudio Guidi <cguidi@italianasoftware.com>     *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Library General Public License as       *
 *   published by the Free Software Foundation; either version 2 of the    *
 *   License, or (at your option) any later version.                       *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU Library General Public     *
 *   License along with this program; if not, write to the                 *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 *                                                                         *
 *   For details about the authors of this software, see the AUTHORS file. *
 ***************************************************************************/
package joliex.surface;

import jolie.lang.NativeType;
import jolie.lang.parse.ast.*;
import jolie.lang.parse.ast.types.TypeChoiceDefinition;
import jolie.lang.parse.ast.types.TypeDefinition;
import jolie.lang.parse.ast.types.TypeDefinitionLink;
import jolie.lang.parse.ast.types.TypeInlineDefinition;
import jolie.lang.parse.util.Interfaces;
import jolie.lang.parse.util.ProgramInspector;
import jolie.util.Range;

import java.io.OutputStream;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map.Entry;

/**
 * @author Claudio Guidi
 *         <p>
 *         Modified by Francesco Bullini, 05/07/2012
 */
public class SurfaceCreator {
    private ProgramInspector inspector;
    private ArrayList<RequestResponseOperationDeclaration> requestResponseOperations;
    private ArrayList<OneWayOperationDeclaration> oneWayOperations;
    private ArrayList<String> types;
    private ArrayList<TypeDefinition> auxTypes;
    private PrintWriter writer;

    public SurfaceCreator(ProgramInspector inspector, OutputStream out) {
        this.inspector = inspector;
        writer = new PrintWriter(out);
    }

    public void init(String inputPortToCreate) throws Exception {

        ArrayList<InterfaceDefinition> interfaces = new ArrayList<>();
        requestResponseOperations = new ArrayList<>();
        oneWayOperations = new ArrayList<>();
        types = new ArrayList<>();
        auxTypes = new ArrayList<>();

        // find inputPort

        InputPortInfo[] inputPortList = inspector.getInputPorts();

        InputPortInfo inputPort = null;
        for (InputPortInfo iP : inputPortList) {
            if (iP.id().equals(inputPortToCreate)) {
                inputPort = iP;
            }
        }
        if (inputPort == null) {
            throw new Exception("Error! inputPort not found!");
        }

        // extracts the list of all the interfaces to be parsed
        // extracts interfaces declared into Interfaces
        interfaces.addAll(inputPort.getInterfaceList());
        OutputPortInfo[] outputPortList = inspector.getOutputPorts();
        // extracts interfaces from aggregated outputPorts
        for (int x = 0; x < inputPort.aggregationList().length; x++) {
            int i = 0;
            while (!inputPort.aggregationList()[x].outputPortList()[0].equals(outputPortList[i].id())) {
                i++;

            }
            for (InterfaceDefinition interfaceDefinition : outputPortList[i].getInterfaceList()) {
                interfaces.add(Interfaces.extend(interfaceDefinition,
                        inputPort.aggregationList()[x].interfaceExtender(), inputPort.id()));
            }
        }

        //  for each interface extract the list of all the available operations and types
        for (InterfaceDefinition interfaceDefinition : interfaces) {
            addOperation(interfaceDefinition);
        }
    }

    private void addOperation(InterfaceDefinition interfaceDefinition) {
        for (OperationDeclaration op : interfaceDefinition.operationsMap().values()) {
            if (op instanceof RequestResponseOperationDeclaration) {
                requestResponseOperations.add((RequestResponseOperationDeclaration) op);
            } else {
                oneWayOperations.add((OneWayOperationDeclaration) op);
            }
        }
    }

    private static String getOWString(OneWayOperationDeclaration ow) {
        return ow.id() + "( " + ow.requestType().id() + " )";
    }

    private static String getRRString(RequestResponseOperationDeclaration rr) {
        StringBuilder ret = new StringBuilder(rr.id() + "( " + rr.requestType().id() + " )( " + rr.responseType().id() + " )");
        if (rr.faults().size() > 0) {
            ret.append(" throws ");
            boolean flag = false;
            for (Entry<String, TypeDefinition> fault : rr.faults().entrySet()) {
                if (!flag) {
                    flag = true;
                } else {
                    ret.append(" ");
                }
                ret.append(fault.getKey());
                if (fault.getValue() != null) {
                    ret.append("( ").append(fault.getValue().id()).append(" )");
                }
            }
        }
        return ret.toString();
    }

    private String getMax(int max) {
        if (max == Integer.MAX_VALUE) {
            return "*";
        } else {
            return Integer.toString(max);
        }
    }

    private String getCardinality(Range card) {
        return (card.min() == 1 && card.max() == 1) ? "" : ("[" + card.min() + "," + getMax(card.max()) + "]");
    }

    private boolean choice;

    private String getSubType(TypeDefinition type, int indent) {
        StringBuilder ret = new StringBuilder();

        if (choice) {
            choice = false;
        } else {
            for (int y = 0; y < indent; y++) {
                ret.append("\t");
            }

            ret.append(".").append(type.id()).append(getCardinality(type.cardinality())).append(":");
        }

        if (type instanceof TypeDefinitionLink) {
            ret.append(((TypeDefinitionLink) type).linkedTypeName());
            if (!auxTypes.contains(((TypeDefinitionLink) type).linkedType())) {
                auxTypes.add(((TypeDefinitionLink) type).linkedType());
            }

        } else if (type instanceof TypeInlineDefinition) {
            TypeInlineDefinition def = (TypeInlineDefinition) type;
            ret.append(def.nativeType().id());
            if (def.hasSubTypes()) {
                ret.append("{ \n");
                for (Entry<String, TypeDefinition> entry : def.subTypes()) {
                    ret.append(getSubType(entry.getValue(), indent + 1)).append("\n");
                }
                for (int y = 0; y < indent; y++) {
                    ret.append("\t");
                }
                ret.append("}");
            } else if (((TypeInlineDefinition) type).untypedSubTypes()) {
                ret.append("{ ? }");
            }
        } else if (type instanceof TypeChoiceDefinition) {
            choice = true;
            ret.append(getSubType(((TypeChoiceDefinition) type).left(), indent)).append(" | ");
            choice = true;
            ret.append(getSubType(((TypeChoiceDefinition) type).right(), indent));

        }

        return ret.toString();
    }

    private String getType(TypeDefinition type) {
        String ret = "";
        if (!types.contains(type.id()) && !NativeType.isNativeTypeKeyword(type.id()) && !type.id().equals("undefined")) {

            writer.print("type " + type.id() + ":");
            checkType(type);
            writer.println("");
            types.add(type.id());
        }

        return ret;
    }

    private void checkType(TypeDefinition type) {
        if (type instanceof TypeDefinitionLink) {
            writer.print(((TypeDefinitionLink) type).linkedTypeName());
            if (!auxTypes.contains(((TypeDefinitionLink) type).linkedType())) {
                auxTypes.add(((TypeDefinitionLink) type).linkedType());
            }
        } else if (type instanceof TypeInlineDefinition) {
            TypeInlineDefinition def = (TypeInlineDefinition) type;
            writer.print(def.nativeType().id());
            if (def.hasSubTypes()) {
                writer.print("{\n");
                for (Entry<String, TypeDefinition> entry : def.subTypes()) {
                    writer.print(getSubType(entry.getValue(), 1) + "\n");
                }

                writer.print("}");
            } else {

                if (((TypeInlineDefinition) type).untypedSubTypes()) {
                    writer.print(" { ? }");
                }

            }
        } else if (type instanceof TypeChoiceDefinition) {
            checkType(((TypeChoiceDefinition) type).left());
            writer.print(" | ");
            checkType(((TypeChoiceDefinition) type).right());
        }

    }

    private void printType(String type) {
        if (!type.equals("")) {
            writer.println(type);
        }

    }

    public void createOutput(InputPortInfo inputPort) {
        // types creation
        if (oneWayOperations.size() > 0) {
            for (OneWayOperationDeclaration anOw_vector : oneWayOperations) {
                //writer.println("// types for operation " + oneWayOperations.get(x).id() );
                printType(getType(anOw_vector.requestType()));
            }
            writer.println();
        }

        if (requestResponseOperations.size() > 0) {
            for (RequestResponseOperationDeclaration aRr_vector : requestResponseOperations) {
                //writer.println("// types for operation " + requestResponseOperations.get(x).id() );
                printType(getType(aRr_vector.requestType()));
                printType(getType(aRr_vector.responseType()));
                for (Entry<String, TypeDefinition> fault : aRr_vector.faults().entrySet()) {
                    if (!fault.getValue().id().equals("undefined")) {
                        writer.println(getType(fault.getValue()));
                    }
                }
            }
            writer.println();
        }

        // add auxiliary types
        while (!auxTypes.isEmpty()) {
            ArrayList<TypeDefinition> aux_types_temp_vector = new ArrayList<>();
            aux_types_temp_vector.addAll(auxTypes);
            auxTypes.clear();
            for (Object anAux_types_temp_vector : aux_types_temp_vector) {
                printType(getType((TypeDefinition) anAux_types_temp_vector));
            }
        }

        writer.println();


    }

    public void writeInterface(String interfaceName,
                               List<OneWayOperationDeclaration> oneWayOperations,
                               List<RequestResponseOperationDeclaration> requestResponseOperations) {
        // interface creation
        writer.println("interface " + interfaceName + " {");
        // oneway declaration
        if (oneWayOperations.size() > 0) {
            writer.println("OneWay:");
            for (int x = 0; x < oneWayOperations.size(); x++) {
                if (x != 0) {
                    writer.println(",");
                }
                writer.print("\t" + getOWString(oneWayOperations.get(x)));
            }
            writer.println();
        }
        // request response declaration
        if (requestResponseOperations.size() > 0) {
            writer.println("RequestResponse:");
            for (int x = 0; x < requestResponseOperations.size(); x++) {
                if (x != 0) {
                    writer.println(",");
                }
                writer.print("\t" + getRRString(requestResponseOperations.get(x)));
            }
            writer.println();
        }
        writer.println("}");
        writer.println();
    }
}
