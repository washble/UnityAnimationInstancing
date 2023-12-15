using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

public class CharacterMove : MonoBehaviour
{
    [SerializeField] public URPAnimationInstancing attachAnimationInstancing;
    [SerializeField] private string attachBoneName;
    [SerializeField] private Vector3 goalPosition = new Vector3(26052, 0, 25133);
    
    private URPAnimationInstancing animationInstancing;
    private NavMeshAgent navMeshAgent;
    
    private WaitForSeconds wait = new WaitForSeconds(1.5f);
    [SerializeField]
    private bool isAnimation = false;
    
    private void Awake()
    {
        animationInstancing = GetComponent<URPAnimationInstancing>();
        navMeshAgent = GetComponent<NavMeshAgent>();

        if (!navMeshAgent)
        {
            enabled = false;
        }
    }
    
    private void OnEnable()
    {
        StartCoroutine(AnimationStart());
    }

    private void Update()
    {
        if (isAnimation)
        {
            navMeshAgent.SetDestination(goalPosition);
        }
    }

    private void OnDestroy()
    {
        isAnimation = false;
        StopAllCoroutines();
    }

    private IEnumerator AnimationStart()
    {
        yield return null;

        navMeshAgent.enabled = true;
        isAnimation = true;
        animationInstancing.Attach(attachBoneName, attachAnimationInstancing);
        while (isAnimation)
        {
            animationInstancing.PlayAnimation(0);
            yield return wait;
            animationInstancing.PlayAnimation(1);
            yield return wait;
        }   
    }
}
