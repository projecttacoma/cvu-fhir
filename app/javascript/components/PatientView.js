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
  ServiceRequestVisualizer,
  DeviceRequestVisualizer,
  CommunicationVisualizer,
  CoverageVisualizer,
  AdverseEventVisualizer,
  NutritionOrderVisualizer,
  MedicationRequestVisualizer,
  MedicationAdministrationVisualizer,
  MedicationDispenseVisualizer
} from 'fhir-visualizers';
import ReactModal from "react-modal";

class PatientView extends React.Component {
  constructor(props) {
    super(props);

    this.showDetails = this.showDetails.bind(this);
    this.handleCloseModal = this.handleCloseModal.bind(this);
    this.classForEntry = this.classForEntry.bind(this);

    this.state = {
      entryDetail: null,
      entryErrors: null,
      showModal: false
    };
    ReactModal.setAppElement(document.body);
  }

  showDetails(entry){
    this.setState({
      entryDetail: entry,
      entryErrors: this.props.errors[entry.id],
      showModal: true
    });
  }

  classForEntry(entry){
    let errors = this.props.errors[entry.id];
    if(errors['errors'].length>0){
      return 'row-error';
    }else if(errors['warnings'].length>0){
      return 'row-warning';
    }else{
      return '';
    }
  }

  handleCloseModal () {
    this.setState({ showModal: false });
  }

  render () {
  	let data = { /* ... */ };
    console.log(this.props.entry.filter(e => e.resource.resourceType == 'Encounter').map(e => e.resource))
    // TODO: check report is observation? and add document references?
    return (
      <React.Fragment><div className="patient-view">
        <div><PatientVisualizer patient={this.props.patient} /></div>
        <div>Patient Errors: <ObjectInspector data={ this.props.errors[this.props.patient.id] } /></div>

        <div><EncountersVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'Encounter').map(e => e.resource)} /></div>
        <div><ConditionsVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'Condition').map(e => e.resource)} /></div>
        <div><ObservationsVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'Observation').map(e => e.resource)} /></div>
        <div><MedicationsVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'Medication').map(e => e.resource)} /></div>
        <div><AllergiesVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'Allergy').map(e => e.resource)} /></div>
        <div><ReportsVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'Observation').map(e => e.resource)} /></div>
        <div><CarePlansVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'CarePlan').map(e => e.resource)} /></div>
        <div><ProceduresVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'Procedure').map(e => e.resource)} /></div>
        <div><ImmunizationsVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'Immunization').map(e => e.resource)} /></div>
        <div><ServiceRequestVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'ServiceRequest').map(e => e.resource)} /></div>
        <div><DeviceRequestVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'DeviceRequest').map(e => e.resource)} /></div>
        <div><CommunicationVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'Communication').map(e => e.resource)} /></div>
        <div><CoverageVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'Coverage').map(e => e.resource)} /></div>
        <div><AdverseEventVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'AdverseEvent').map(e => e.resource)} /></div>
        <div><NutritionOrderVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'NutritionOrder').map(e => e.resource)} /></div>
        <div><MedicationRequestVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'MedicationRequest').map(e => e.resource)} /></div>
        <div><MedicationAdministrationVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'MedicationAdministration').map(e => e.resource)} /></div>
        <div><MedicationDispenseVisualizer onRowClick={this.showDetails} dynamicRowClass={this.classForEntry} rows={this.props.entry.filter(e => e.resource.resourceType == 'MedicationDispense').map(e => e.resource)} /></div>
        
        <ReactModal
           isOpen={this.state.showModal}
           contentLabel="Entry details modal"
           style={{
            content: {
              width: '50%',
              height: '50%',
              margin: 'auto'
            }
          }}
        >
          <div>Entry Detail: <ObjectInspector data={ this.state.entryDetail } /></div>
          <br/>
          <div>Entry Errors: <ObjectInspector data={ this.state.entryErrors } /></div>
          <br/>
          <button onClick={this.handleCloseModal}>Close</button>
        </ReactModal>
      </div></React.Fragment>
    );
  }
}

PatientView.propTypes = {
};
export default PatientView
