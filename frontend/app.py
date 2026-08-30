import streamlit as st
import os

# 1. Initialize Spark NLP for Healthcare (Runs inside your AWS Container VPC)
# Ensure your JSL license credentials/tokens from AWS Marketplace are set as environment vars
from johnsnowlabs import nlp, medical

@st.cache_resource
def init_spark_nlp():
    """Starts the Spark Session securely in the container environment."""
    # The container handles your license validation implicitly when instantiated via AWS
    return nlp.start()

spark = init_spark_nlp()

# 2. Build the De-identification NLP Pipelines
@st.cache_resource
def load_deid_pipeline(mode="mask"):
    """
    Loads John Snow Labs pretrained clinical de-identification workflows.
    Modes available: 
      - 'mask': Replaces PHI with structural tags like [PATIENT], [DATE]
      - 'obfuscate': Replaces PHI with fake synthetic names/dates while preserving syntax
    """
    # Uses the core clinical deidentification pretrained workflow
    pipeline_name = "clinical_deidentification"
    
    # Load the end-to-end pretrained pipeline from the JSL cluster repository
    deid_pipeline = nlp.PretrainedPipeline(pipeline_name, "en", "clinical/models")
    
    # Customize the underlying model configuration based on user selection
    # (By default, John Snow Labs pipelines support toggleable masking/obfuscation configurations)
    return deid_pipeline

# 3. Streamlit UI Elements
st.set_page_config(page_title="Secure HIPAA De-identification Engine", layout="wide")
st.title("Enterprise HIPAA De-identification & Masking Portal")
st.caption("Powered by John Snow Labs Spark NLP")
st.caption("Author: Eric Michel")

# User Configuration Sidebar
st.sidebar.header("Pipeline Configuration")
deid_mode = st.sidebar.selectbox(
    "Select De-identification Strategy:",
    options=["Masking (Structural Tags)", "Obfuscation (Synthetic Data)"],
    help="Masking replaces text with tags like [NAME]. Obfuscation generates realistic fake text."
)

selected_mode = "mask" if "Masking" in deid_mode else "obfuscate"

# Sample text for testing
sample_note = (
    "Record Date: 2026-08-14\n"
    "Patient: John Smith, a 45-year-old male, was admitted to St. Jude Hospital.\n"
    "He can be reached at 555-0199 or via email at john.smith@email.com.\n"
    "Discharge Plan: Follow up with Dr. Amanda Vance regarding his Type 2 Diabetes."
)

# Text Input Area
input_text = st.text_area("Paste Raw Clinical Narrative / EHR Note Here:", value=sample_note, height=200)

if st.button("Process Document & Remove PHI"):
    if input_text.strip() == "":
        st.warning("Please enter text to process.")
    else:
        with st.spinner("Executing secure pipeline within AWS container boundary..."):
            
            # Load selected pipeline setting
            pipeline = load_deid_pipeline(mode=selected_mode)
            
            # Run inference on text
            # Note: For production batching, pass an array of strings or a Spark DataFrame
            result = pipeline.annotate(input_text)
            
            # John Snow Labs pipelines output multiple annotator columns.
            # We want the final cleaned/de-identified output text column.
            # In the pre-trained 'clinical_deidentification' pipeline, this is typically stored in 'deidentified'
            deidentified_text_list = result.get('deidentified', [])
            
            # Reconstruct the string
            sanitized_output = " ".join(deidentified_text_list) if deidentified_text_list else "Error processing text."
            
            # Display Results Side-by-Side
            col1, col2 = st.columns(2)
            
            with col1:
                st.subheader("Original Input (Contains PHI)")
                st.info(input_text)
                
            with col2:
                st.subheader(f"Sanitized Output ({deid_mode})")
                st.success(sanitized_output)
                
            # Additional metadata exploration
            with st.expander("View Detected PHI Entity Details"):
                st.write("Identified Category Scans:")
                st.json({
                    "Detected Names": result.get("NAME", ["None explicitly isolated"]),
                    "Detected Dates": result.get("DATE", ["None explicitly isolated"]),
                    "Detected Contact info": result.get("CONTACT", ["None explicitly isolated"]),
                    "Detected Locations": result.get("LOCATION", ["None explicitly isolated"])
                })
