import React from "react"
import PropTypes from "prop-types"
import ObjectInspector from "react-object-inspector"
import { 
  PatientVisualizer,
  ConditionsVisualizer,
  ObservationsVisualizer,
  ReportsVisualizer,
  MedicationsVisualizer,
  AllergiesVisualizer,
  CarePlansVisualizer,
  ProceduresVisualizer,
  EncountersVisualizer,
  ImmunizationsVisualizer,
  DocumentReferencesVisualizer
} from 'fhir-visualizers';

class HelloWorld extends React.Component {
  render () {
  	let data = { /* ... */ };
    return (
      <React.Fragment>
        <div><PatientVisualizer patient={this.props.patient} /></div>
        <div>FHIR Resource: <ObjectInspector data={ this.props.data } /></div>
        <div>Errors: <ObjectInspector data={ this.props.errors } /></div>
      </React.Fragment>
    );
  }
}

HelloWorld.propTypes = {
  greeting: PropTypes.string
};
export default HelloWorld
