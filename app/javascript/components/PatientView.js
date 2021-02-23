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

class PatientView extends React.Component {
  render () {
  	let data = { /* ... */ };
    console.log(this.props.entry.filter(e => e.resource.resourceType == 'Encounter').map(e => e.resource))
    // TODO: check report is observation? and add document references?
    return (
      <React.Fragment>
        <div><PatientVisualizer patient={this.props.patient} /></div>
        <div><EncountersVisualizer rows={this.props.entry.filter(e => e.resource.resourceType == 'Encounter').map(e => e.resource)} /></div>
        <div><ConditionsVisualizer rows={this.props.entry.filter(e => e.resource.resourceType == 'Condition').map(e => e.resource)} /></div>
        <div><ObservationsVisualizer rows={this.props.entry.filter(e => e.resource.resourceType == 'Observation').map(e => e.resource)} /></div>
        <div><MedicationsVisualizer rows={this.props.entry.filter(e => e.resource.resourceType == 'Medication').map(e => e.resource)} /></div>
        <div><AllergiesVisualizer rows={this.props.entry.filter(e => e.resource.resourceType == 'Allergy').map(e => e.resource)} /></div>
        <div><ReportsVisualizer rows={this.props.entry.filter(e => e.resource.resourceType == 'Observation').map(e => e.resource)} /></div>
        <div><CarePlansVisualizer rows={this.props.entry.filter(e => e.resource.resourceType == 'CarePlan').map(e => e.resource)} /></div>
        <div><ProceduresVisualizer rows={this.props.entry.filter(e => e.resource.resourceType == 'Procedure').map(e => e.resource)} /></div>
        <div><ImmunizationsVisualizer rows={this.props.entry.filter(e => e.resource.resourceType == 'Immunization').map(e => e.resource)} /></div>
        <div>FHIR Resource: <ObjectInspector data={ this.props.data } /></div>
        <div>Errors: <ObjectInspector data={ this.props.errors } /></div>
      </React.Fragment>
    );
  }
}

PatientView.propTypes = {
  greeting: PropTypes.string
};
export default PatientView
